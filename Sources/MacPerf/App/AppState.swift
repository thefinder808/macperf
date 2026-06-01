import SwiftUI
import Combine
import AppKit

final class AppState: ObservableObject {
    @Published var selectedCategory: MetricCategory? = .overview {
        didSet { if selectedCategory == .processes { refreshProcessesIfNeeded() } }
    }
    @Published var selectedTimeRange: TimeRange = .oneMinute
    @Published var showCommandPalette: Bool = false {
        didSet { if showCommandPalette { refreshProcessesIfNeeded() } }
    }
    @Published var focusProcessSearch: Bool = false
    @Published var showExport: Bool = false
    @Published var showSettings: Bool = false

    // Base sampling interval in seconds. Higher = lower power. Loaded inline so
    // the initial assignment doesn't trigger the didSet timer restart.
    private static let intervalKey = "macperf.samplingInterval"
    @Published var samplingInterval: Double = AppState.loadInterval() {
        didSet {
            guard samplingInterval != oldValue else { return }
            UserDefaults.standard.set(samplingInterval, forKey: Self.intervalKey)
            startTimer()
        }
    }

    private static func loadInterval() -> Double {
        let saved = UserDefaults.standard.double(forKey: intervalKey)
        return [1.0, 2.0, 5.0].contains(saved) ? saved : 1.0
    }

    // Whether the main dashboard window is on-screen and unobscured. Lets us skip
    // work that's only worth doing when the user can actually see it.
    private(set) var isWindowVisible = true
    // Set by StatusBarController while the menu-bar panel is showing.
    var isMenuPanelOpen = false {
        didSet { if isMenuPanelOpen { refreshProcessesIfNeeded() } }
    }

    // Process enumeration walks every running process (the heaviest sample), so
    // only run it when something actually displays process data.
    var needsProcessData: Bool {
        (selectedCategory == .processes && isWindowVisible) || isMenuPanelOpen || showCommandPalette
    }

    func refreshProcessesIfNeeded() {
        if needsProcessData { processVM.update() }
    }

    let systemInfo: SystemInfo

    // All real view models
    let cpuVM = CPUViewModel()
    let memoryVM = MemoryViewModel()
    let diskVM = DiskViewModel()
    let networkVM = NetworkViewModel()
    let gpuVM = GPUViewModel()
    let thermalVM = ThermalViewModel()
    let storageVM = StorageViewModel()
    let batteryVM = BatteryViewModel()
    let processVM = ProcessViewModel()

    // Services
    let alertService = AlertService()

    // Refreshes the menu-bar label directly every tick, independent of the SwiftUI
    // fan-in (which is suppressed while hidden). Set by StatusBarController so the
    // status item keeps updating even when the window isn't visible.
    var menuBarRefresh: (() -> Void)?

    // Convenience accessors for sidebar/overview
    var cpuUsage: Double { cpuVM.overallUsage }
    var cpuSeries: TimeSeries { cpuVM.overallSeries }
    var memoryUsage: Double { memoryVM.totalBytes > 0 ? Double(memoryVM.usedBytes) / Double(memoryVM.totalBytes) * 100 : 0 }
    var memorySeries: TimeSeries { memoryVM.usageSeries }
    var diskReadRate: Double { diskVM.readBytesPerSec }
    var diskReadSeries: TimeSeries { diskVM.readSeries }
    var networkDownRate: Double { networkVM.downloadBytesPerSec }
    var networkDownSeries: TimeSeries { networkVM.downloadSeries }
    var gpuUsage: Double { gpuVM.deviceUtilization }
    var gpuSeries: TimeSeries { gpuVM.deviceUtilSeries }
    var thermalTemp: Double { thermalVM.cpuTemperature }
    var thermalSeries: TimeSeries { thermalVM.cpuTempSeries }
    var batteryLevel: Double { batteryVM.currentPercent }
    var batterySeries: TimeSeries { batteryVM.chargeSeries }
    var hasBattery: Bool { batteryVM.isPresent }

    private var timerSubscription: AnyCancellable?
    private var vmSubscriptions: Set<AnyCancellable> = []
    private var tick: Int = 0

    // While any NSMenu is being tracked (the macOS menu bar's File/Edit/View
    // dropdowns, SwiftUI .contextMenu, etc.), suppress forwarded publishes.
    // Otherwise the App scene's body re-evaluates on every metric tick and
    // SwiftUI replaces the menu bar's NSMenu, cancelling the user's open
    // tracking session — items appear briefly then vanish. The next VM tick
    // after the menu closes refreshes views naturally.
    private var isMenuTracking = false

    init() {
        self.systemInfo = SystemInfo.fetch()

        NotificationCenter.default.addObserver(
            self, selector: #selector(menuStartedTracking),
            name: NSMenu.didBeginTrackingNotification, object: nil)
        NotificationCenter.default.addObserver(
            self, selector: #selector(menuEndedTracking),
            name: NSMenu.didEndTrackingNotification, object: nil)

        // Track whether the dashboard window is visible so we can gate work.
        for name in [NSWindow.didChangeOcclusionStateNotification,
                     NSWindow.willCloseNotification,
                     NSWindow.didMiniaturizeNotification,
                     NSWindow.didDeminiaturizeNotification,
                     NSApplication.didHideNotification,
                     NSApplication.didUnhideNotification,
                     NSApplication.didBecomeActiveNotification,
                     NSApplication.didResignActiveNotification] {
            NotificationCenter.default.addObserver(
                self, selector: #selector(windowVisibilityChanged), name: name, object: nil)
        }

        // Forward child VM changes to trigger our own objectWillChange,
        // except while a menu is being tracked (see isMenuTracking above).
        let vms: [any ObservableObject] = [cpuVM, memoryVM, diskVM, networkVM, gpuVM, thermalVM, storageVM, batteryVM, processVM]
        for vm in vms {
            (vm.objectWillChange as? ObservableObjectPublisher)?.sink { [weak self] _ in
                // Suppress while a menu is tracking, or while hidden (nothing on-screen
                // to update — the menu bar refreshes via menuBarRefresh instead).
                guard let self, !self.isMenuTracking, self.isWindowVisible else { return }
                self.objectWillChange.send()
            }.store(in: &vmSubscriptions)
        }

        startTimer()
    }

    @objc private func menuStartedTracking(_ note: Notification) {
        isMenuTracking = true
    }

    @objc private func menuEndedTracking(_ note: Notification) {
        isMenuTracking = false
    }

    // Recompute on the next runloop pass so the window list reflects the change
    // (e.g. willClose fires before the window leaves NSApp.windows).
    @objc private func windowVisibilityChanged(_ note: Notification) {
        DispatchQueue.main.async { [weak self] in self?.recomputeWindowVisibility() }
    }

    private func recomputeWindowVisibility() {
        // App-level signals catch Cmd-H (isHidden) and full occlusion, which the
        // per-window checks miss; the window check rules out closed/minimized.
        let appShowing = !NSApp.isHidden && NSApp.occlusionState.contains(.visible)
        let hasOnscreenWindow = NSApp.windows.contains { w in
            w.styleMask.contains(.titled) && w.isVisible && !w.isMiniaturized
        }
        let visible = appShowing && hasOnscreenWindow
        guard visible != isWindowVisible else { return }
        isWindowVisible = visible
        if visible {
            // UI updates were suppressed while hidden; refresh the now-visible views.
            objectWillChange.send()
            refreshProcessesIfNeeded()
        }
    }

    deinit {
        timerSubscription?.cancel()
    }

    private func startTimer() {
        timerSubscription = Timer.publish(every: samplingInterval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.update()
            }
    }

    private func update() {
        tick += 1

        // Hidden / minimized / occluded: keep the menu bar's metrics fresh but skip
        // chart history and the SwiftUI fan-in so nothing re-renders off-screen.
        // (The status item stays visible and live even when the app is hidden.)
        guard isWindowVisible else {
            cpuVM.update(appendHistory: false)
            memoryVM.update(appendHistory: false)
            diskVM.update(appendHistory: false)
            networkVM.update(appendHistory: false)
            gpuVM.update(appendHistory: false)
            if tick % 5 == 0 { thermalVM.update(appendHistory: false) }
            menuBarRefresh?()
            return
        }

        // All hardware monitors — every tick (1s)
        cpuVM.update()
        memoryVM.update()
        diskVM.update()
        networkVM.update()
        gpuVM.update()

        // Processes — the heaviest sample; only when something displays it.
        if needsProcessData, tick % 2 == 0 || tick <= 1 {
            processVM.update()
        }

        // Thermal + storage — every 5 ticks (5s) since they change slowly
        if tick % 5 == 0 || tick <= 1 {
            thermalVM.update()
            storageVM.update()
            batteryVM.update()
        }

        // Alert checks — every 5 ticks
        if tick % 5 == 0 {
            alertService.check(
                cpuUsage: cpuUsage,
                memoryPressure: memoryVM.pressureLevel,
                thermalState: thermalVM.thermalState,
                volumes: storageVM.volumes
            )
        }

        menuBarRefresh?()
    }
}
