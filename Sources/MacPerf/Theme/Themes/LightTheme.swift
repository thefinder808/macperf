import SwiftUI

struct LightTheme: AppTheme {
    let name = "Light"

    var windowBackground: Color { Color(red: 0.96, green: 0.96, blue: 0.97) }
    var sidebarBackground: Color { Color.white }
    var cardBackground: Color { Color.white }
    var graphBackground: Color { Color.white }

    var border: Color { Color(red: 0.82, green: 0.82, blue: 0.84) }
    var gridLine: Color { Color(red: 0.91, green: 0.91, blue: 0.93) }

    var primaryText: Color { Color(red: 0.11, green: 0.11, blue: 0.12) }
    var secondaryText: Color { Color(red: 0.43, green: 0.43, blue: 0.45) }
    var tertiaryText: Color { Color(red: 0.557, green: 0.557, blue: 0.576) }

    var sidebarHover: Color { Color(red: 0.94, green: 0.94, blue: 0.96) }
    var sidebarActive: Color { Color(red: 0.91, green: 0.91, blue: 0.93) }
    var tableRowHover: Color { Color.black.opacity(0.03) }

    var trackBackground: Color { Color(red: 0.91, green: 0.91, blue: 0.93) }

    func accent(for category: MetricCategory) -> Color {
        switch category {
        case .overview: return Color(red: 0.15, green: 0.39, blue: 0.92)
        case .cpu: return Color(red: 0.15, green: 0.39, blue: 0.92)       // #2563EB
        case .memory: return Color(red: 0.49, green: 0.23, blue: 0.93)    // #7C3AED
        case .disk: return Color(red: 0.02, green: 0.59, blue: 0.41)      // #059669
        case .network: return Color(red: 0.85, green: 0.47, blue: 0.02)   // #D97706
        case .gpu: return Color(red: 0.05, green: 0.58, blue: 0.53)       // #0D9488
        case .thermal: return Color(red: 0.86, green: 0.15, blue: 0.15)   // #DC2626
        case .battery: return Color(red: 0.13, green: 0.59, blue: 0.25)   // #219B40
        case .processes: return Color(red: 0.42, green: 0.45, blue: 0.50) // #6B7280
        case .storage: return Color(red: 0.31, green: 0.30, blue: 0.76)   // #4F46E5
        }
    }
}
