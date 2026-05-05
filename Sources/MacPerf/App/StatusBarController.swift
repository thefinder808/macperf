import AppKit
import SwiftUI
import Combine

final class StatusBarController {
    private var statusItem: NSStatusItem
    private var panel: NSPanel
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()
    private var updateTimer: AnyCancellable?

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
        }

        // Observe changes to update the label
        appState.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateLabel() }
        }.store(in: &cancellables)

        settingsManager.objectWillChange.sink { [weak self] _ in
            DispatchQueue.main.async { self?.updateLabel() }
        }.store(in: &cancellables)

        updateLabel()
    }

    private func updateLabel() {
        guard let button = statusItem.button else { return }

        let font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
        button.font = font

        if settingsManager.useTextLabels {
            button.image = nil
            button.attributedTitle = NSAttributedString()
            button.title = settingsManager.menuBarLabel(from: appState)
            return
        }

        let metrics = settingsManager.sortedEnabledMetrics
        guard !metrics.isEmpty else {
            let image = NSImage(systemSymbolName: "gauge.medium", accessibilityDescription: nil)
            image?.isTemplate = true
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
                composed.append(NSAttributedString(string: "  ", attributes: [.font: font]))
            }
            if let symbol = NSImage(systemSymbolName: metric.systemImage, accessibilityDescription: metric.rawValue) {
                symbol.isTemplate = true
                let attachment = NSTextAttachment()
                attachment.image = symbol
                attachment.bounds = NSRect(x: 0, y: -3, width: 14, height: 14)
                composed.append(NSAttributedString(attachment: attachment))
            }
            composed.append(NSAttributedString(
                string: " " + metric.formatValue(from: appState),
                attributes: [.font: font]
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
        panel.orderOut(nil)
        if let monitor = eventMonitor {
            NSEvent.removeMonitor(monitor)
            eventMonitor = nil
        }
    }
}
