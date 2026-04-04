import AppKit
import SwiftUI
import Combine

final class StatusBarController {
    private var statusItem: NSStatusItem
    private var popover: NSPopover
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
        self.popover = NSPopover()

        let hostingView = NSHostingController(
            rootView: MenuBarView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
        )
        popover.contentViewController = hostingView
        popover.behavior = .transient

        if let button = statusItem.button {
            button.action = #selector(togglePopover(_:))
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

        let text = settingsManager.menuBarLabel(from: appState)

        if settingsManager.useTextLabels {
            // Text labels only, no icon
            button.image = nil
            button.title = text
        } else {
            // Icon + values
            let iconName = settingsManager.sortedEnabledMetrics.first?.systemImage ?? "gauge.medium"
            let image = NSImage(systemSymbolName: iconName, accessibilityDescription: nil)
            image?.size = NSSize(width: 16, height: 16)
            button.image = image
            button.imagePosition = .imageLeading
            button.title = " \(text)"
        }

        button.font = NSFont.monospacedDigitSystemFont(ofSize: 12, weight: .regular)
    }

    @objc private func togglePopover(_ sender: AnyObject?) {
        if popover.isShown {
            popover.performClose(sender)
        } else if let button = statusItem.button {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        }
    }
}
