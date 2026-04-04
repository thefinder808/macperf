import SwiftUI

struct LightTheme: AppTheme {
    let name = "Light"
    var cardShadow: Bool { true }

    var windowBackground: Color { Color(hex: 0xF8F8FA) }
    var sidebarBackground: Color { Color(hex: 0xF2F2F7) }
    var cardBackground: Color { Color.white }
    var graphBackground: Color { Color.white }

    var border: Color { Color(hex: 0xE8E8EC) }
    var gridLine: Color { Color(hex: 0xE8E8EC) }

    var primaryText: Color { Color(hex: 0x1D1D1F) }
    var secondaryText: Color { Color(hex: 0x86868B) }
    var tertiaryText: Color { Color(hex: 0xAEAEB2) }

    var sidebarHover: Color { Color(red: 0.94, green: 0.94, blue: 0.96) }
    var sidebarActive: Color { Color(red: 0.91, green: 0.91, blue: 0.93) }
    var tableRowHover: Color { Color.black.opacity(0.03) }

    var trackBackground: Color { Color(hex: 0xF2F2F7) }

    func accent(for category: MetricCategory) -> Color {
        switch category {
        case .overview: return Color(hex: 0x007AFF)
        case .cpu: return Color(hex: 0x007AFF)       // Apple Blue
        case .memory: return Color(hex: 0xAF52DE)     // Apple Purple
        case .disk: return Color(hex: 0x34C759)       // Apple Green
        case .network: return Color(hex: 0xFF9500)     // Apple Orange
        case .gpu: return Color(hex: 0x5AC8FA)         // Apple Teal
        case .thermal: return Color(hex: 0xFF3B30)     // Apple Red
        case .battery: return Color(hex: 0x34C759)     // Apple Green
        case .processes: return Color(hex: 0x8E8E93)   // Apple Gray
        case .storage: return Color(hex: 0x5856D6)     // Apple Indigo
        }
    }
}
