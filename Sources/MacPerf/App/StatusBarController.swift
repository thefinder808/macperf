import AppKit
import SwiftUI
import Combine

final class StatusBarController {
    private var statusItem: NSStatusItem
    private var panel: NSPanel
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    // Cached once. Recreating NSImage(systemSymbolName:) every tick re-parses the
    // symbol's SVG and leaks CoreSVG allocations — the source of the runaway RAM
    // growth. Cache the template images and the font so a refresh allocates nothing.
    private let labelFont = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    private var symbolCache: [String: NSImage] = [:]
    // The last rendered content key; identical ticks skip the redraw entirely.
    private var lastRenderedKey: String?
    // Ticks since the label was last actually applied to the button.
    private var ticksSinceRender = 0

    private let appState: AppState
    private let settingsManager: SettingsManager
    private let themeManager: ThemeManager

    init(appState: AppState, settingsManager: SettingsManager, themeManager: ThemeManager) {
        self.appState = appState
        self.settingsManager = settingsManager
        self.themeManager = themeManager

        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        // Use NSPanel instead of NSPopover so it appears over fullscreen apps
        let hostingView = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 10))
        )

        let panel = NSPanel(
            contentRect: .zero,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: true
        )
        panel.contentViewController = hostingView
        panel.level = .statusBar
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .transient]
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = true
        self.panel = panel

        if let button = statusItem.button {
            button.action = #selector(togglePanel(_:))
            button.target = self
            button.font = labelFont
        }

        // Refresh the label every tick via a direct hook. Unlike observing
        // appState.objectWillChange, this keeps updating while the app is hidden
        // (the SwiftUI fan-in is suppressed then) so the status item stays live.
        appState.menuBarRefresh = { [weak self] in self?.updateLabel() }
        appState.closeMenuPanel = { [weak self] in self?.closePanel() }

        settingsManager.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateLabel() }
        }.store(in: &cancellables)

        updateLabel()
    }

    /// Returns a cached template image for an SF Symbol, creating it once.
    private func templateSymbol(_ name: String) -> NSImage? {
        if let cached = symbolCache[name] { return cached }
        guard let image = NSImage(systemSymbolName: name, accessibilityDescription: name) else { return nil }
        image.isTemplate = true
        symbolCache[name] = image
        return image
    }

    private func updateLabel() {
        guard let button = statusItem.button else { return }

        let useText = settingsManager.useTextLabels
        let metrics = settingsManager.sortedEnabledMetrics

        // Skip the entire rebuild (and the menu-bar redraw it triggers) when the
        // content is unchanged from the last render — true for most ticks, since
        // values are rounded. This avoids needless NSAttributedString churn.
        let key: String
        if useText {
            key = "T|" + settingsManager.menuBarLabel(from: appState)
        } else if metrics.isEmpty {
            key = "E"
        } else {
            key = "I|" + metrics.map { "\($0.rawValue):\($0.formatValue(from: appState))" }.joined(separator: "|")
        }
        if key == lastRenderedKey {
            ticksSinceRender += 1
            // Re-apply even unchanged content periodically: AppKit can transiently
            // drop a status button's content (space switches, wake, menu-bar
            // re-materialize), and on an idle machine the rounded values can stay
            // identical for minutes — without this the dedup would leave the item
            // blank until a value happens to change. Images stay cached, so this
            // never re-parses symbols (the CoreSVG leak the dedup exists to avoid).
            guard ticksSinceRender >= 10 else { return }
        }
        ticksSinceRender = 0
        lastRenderedKey = key

        if useText {
            button.image = nil
            button.attributedTitle = NSAttributedString()
            button.title = settingsManager.menuBarLabel(from: appState)
            return
        }

        guard !metrics.isEmpty else {
            let image = templateSymbol("gauge.medium")
            image?.size = NSSize(width: 16, height: 16)
            button.image = image
            button.imagePosition = .imageLeading
            button.attributedTitle = NSAttributedString()
            button.title = " —"
            return
        }

        button.image = nil
        button.imagePosition = .noImage

        let composed = NSMutableAttributedString()
        for (i, metric) in metrics.enumerated() {
            if i > 0 {
                composed.append(NSAttributedString(string: "  ", attributes: [.font: labelFont]))
            }
            if let symbol = templateSymbol(metric.systemImage) {
                let attachment = NSTextAttachment()
                attachment.image = symbol
                attachment.bounds = NSRect(x: 0, y: -3, width: 14, height: 14)
                composed.append(NSAttributedString(attachment: attachment))
            }
            composed.append(NSAttributedString(
                string: " " + metric.formatValue(from: appState),
                attributes: [.font: labelFont]
            ))
        }
        button.attributedTitle = composed
    }

    @objc private func togglePanel(_ sender: AnyObject?) {
        if panel.isVisible {
            closePanel()
        } else {
            openPanel()
        }
    }

    private func openPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window else { return }

        // Mark the panel open first; its didSet refreshes process data synchronously
        // so the panel lays out with fresh process counts.
        appState.isMenuPanelOpen = true

        // Size panel to fit its content
        panel.contentViewController?.view.needsLayout = true
        panel.contentViewController?.view.layoutSubtreeIfNeeded()
        let size = panel.contentViewController?.view.fittingSize ?? NSSize(width: 280, height: 400)

        // Position below the status bar button
        let buttonRect = button.convert(button.bounds, to: nil)
        let screenRect = buttonWindow.convertToScreen(buttonRect)
        let x = screenRect.midX - size.width / 2
        let y = screenRect.minY - size.height - 4

        panel.setFrame(NSRect(x: x, y: y, width: size.width, height: size.height), display: true)
        panel.makeKeyAndOrderFront(nil)

        // Dismiss when clicking outside (like transient popover behavior)
        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func closePanel() {
        appState.isMenuPanelOpen = false
        panel.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
