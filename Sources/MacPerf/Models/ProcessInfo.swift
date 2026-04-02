import Foundation

struct ProcessEntry: Identifiable {
    let id: Int32           // pid
    let pid: Int32
    let parentPid: Int32
    let name: String
    var cpuUsage: Double    // percentage 0-100
    var memoryBytes: UInt64
    var gpuUsage: Double    // percentage 0-100
    var energyImpact: EnergyLevel
    var diskReadBytesPerSec: Double
    var diskWriteBytesPerSec: Double
    var threadCount: Int32
    var state: ProcessState

    enum ProcessState: String {
        case running = "Running"
        case sleeping = "Sleeping"
        case idle = "Idle"
        case stopped = "Stopped"
        case zombie = "Zombie"
        case unknown = "Unknown"
    }

    enum EnergyLevel: String, Comparable {
        case low = "Low"
        case medium = "Medium"
        case high = "High"

        var sortOrder: Int {
            switch self {
            case .low: return 0
            case .medium: return 1
            case .high: return 2
            }
        }

        static func < (lhs: EnergyLevel, rhs: EnergyLevel) -> Bool {
            lhs.sortOrder < rhs.sortOrder
        }
    }
}
