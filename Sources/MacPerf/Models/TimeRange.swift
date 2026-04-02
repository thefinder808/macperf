import Foundation

enum TimeRange: String, CaseIterable, Identifiable {
    case oneMinute = "1m"
    case fiveMinutes = "5m"
    case fifteenMinutes = "15m"
    case oneHour = "1h"

    var id: String { rawValue }

    var seconds: Int {
        switch self {
        case .oneMinute: return 60
        case .fiveMinutes: return 300
        case .fifteenMinutes: return 900
        case .oneHour: return 3600
        }
    }

    var label: String { rawValue }
}
