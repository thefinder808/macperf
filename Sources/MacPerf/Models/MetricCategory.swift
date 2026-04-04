import SwiftUI

enum MetricCategory: String, CaseIterable, Identifiable, Hashable {
    case overview = "Overview"
    case cpu = "CPU"
    case memory = "Memory"
    case disk = "Disk"
    case network = "Network"
    case gpu = "GPU"
    case thermal = "Thermal"
    case battery = "Battery"
    case processes = "Processes"
    case storage = "Storage"

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .overview: return "square.grid.2x2"
        case .cpu: return "cpu"
        case .memory: return "memorychip"
        case .disk: return "internaldrive"
        case .network: return "network"
        case .gpu: return "rectangle.3.group"
        case .thermal: return "thermometer.medium"
        case .battery: return "battery.100percent"
        case .processes: return "list.bullet.rectangle"
        case .storage: return "externaldrive"
        }
    }

    var isHardwareMonitor: Bool {
        switch self {
        case .overview, .processes, .storage: return false
        default: return true
        }
    }

    /// Categories that appear in the sidebar's hardware section
    static var hardwareCategories: [MetricCategory] {
        [.cpu, .memory, .disk, .network, .gpu, .thermal, .battery]
    }

    /// Categories that appear in the sidebar's system section
    static var systemCategories: [MetricCategory] {
        [.processes, .storage]
    }
}
