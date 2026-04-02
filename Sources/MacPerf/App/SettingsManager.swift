import SwiftUI
import Combine

enum MenuBarMetric: String, CaseIterable, Identifiable, Hashable {
    case cpu = "CPU"
    case memory = "Memory"
    case gpu = "GPU"
    case disk = "Disk"
    case network = "Network"
    case thermal = "Thermal"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .gpu: return "gpu"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .thermal: return "thermometer.medium"
        }
    }

    /// Order for display in the status bar (left to right)
    var sortOrder: Int {
        switch self {
        case .cpu: return 0
        case .memory: return 1
        case .gpu: return 2
        case .disk: return 3
        case .network: return 4
        case .thermal: return 5
        }
    }

    func formatValue(from appState: AppState) -> String {
        switch self {
        case .cpu: return "\(Int(appState.cpuUsage))%"
        case .memory: return "\(Int(appState.memoryUsage))%"
        case .gpu: return "\(Int(appState.gpuUsage))%"
        case .disk: return Formatters.formatBytesPerSec(appState.diskReadRate)
        case .network: return Formatters.formatBytesPerSec(appState.networkDownRate)
        case .thermal: return Formatters.formatTemperature(appState.thermalTemp)
        }
    }
}

final class SettingsManager: ObservableObject {
    private static let metricsKey = "macperf.menuBarMetrics"

    @Published var enabledMenuBarMetrics: Set<MenuBarMetric> {
        didSet { save() }
    }

    init() {
        if let saved = UserDefaults.standard.array(forKey: Self.metricsKey) as? [String] {
            let metrics = saved.compactMap { MenuBarMetric(rawValue: $0) }
            self.enabledMenuBarMetrics = Set(metrics)
        } else {
            self.enabledMenuBarMetrics = [.cpu, .memory]
        }
    }

    private func save() {
        let raw = enabledMenuBarMetrics.map(\.rawValue)
        UserDefaults.standard.set(raw, forKey: Self.metricsKey)
    }

    /// Sorted enabled metrics for consistent display order
    var sortedEnabledMetrics: [MenuBarMetric] {
        enabledMenuBarMetrics.sorted { $0.sortOrder < $1.sortOrder }
    }

    func menuBarLabel(from appState: AppState) -> String {
        let parts = sortedEnabledMetrics.map { $0.formatValue(from: appState) }
        return parts.isEmpty ? "—" : parts.joined(separator: " ")
    }
}
