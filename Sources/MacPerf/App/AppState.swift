import SwiftUI
import Combine

final class AppState: ObservableObject {
    @Published var selectedCategory: MetricCategory = .overview
    @Published var selectedTimeRange: TimeRange = .oneMinute
    @Published var showCommandPalette: Bool = false
    @Published var focusProcessSearch: Bool = false
    @Published var showExport: Bool = false
    @Published var showSettings: Bool = false

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

    init() {
        self.systemInfo = SystemInfo.fetch()

        // Forward child VM changes to trigger our own objectWillChange
        let vms: [any ObservableObject] = [cpuVM, memoryVM, diskVM, networkVM, gpuVM, thermalVM, storageVM, batteryVM, processVM]
        for vm in vms {
            (vm.objectWillChange as? ObservableObjectPublisher)?.sink { [weak self] _ in
                self?.objectWillChange.send()
            }.store(in: &vmSubscriptions)
        }

        startTimer()
    }

    deinit {
        timerSubscription?.cancel()
    }

    private func startTimer() {
        timerSubscription = Timer.publish(every: 1.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.update()
            }
    }

    private func update() {
        tick += 1

        // All hardware monitors — every tick (1s)
        cpuVM.update()
        memoryVM.update()
        diskVM.update()
        networkVM.update()
        gpuVM.update()

        // Processes — every 2 ticks (2s), heavier than counter reads
        if tick % 2 == 0 || tick <= 1 {
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
    }
}
