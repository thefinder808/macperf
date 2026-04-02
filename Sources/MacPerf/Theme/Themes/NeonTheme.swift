import SwiftUI

struct NeonTheme: AppTheme {
    let name = "Neon"

    var windowBackground: Color { Color(red: 0.04, green: 0.04, blue: 0.06) }
    var sidebarBackground: Color { Color(red: 0.055, green: 0.055, blue: 0.086) }
    var cardBackground: Color { Color(red: 0.067, green: 0.067, blue: 0.094) }
    var graphBackground: Color { Color(red: 0.055, green: 0.055, blue: 0.086) }

    var border: Color { Color(red: 0.10, green: 0.10, blue: 0.18) }
    var gridLine: Color { Color(red: 0.10, green: 0.10, blue: 0.18) }

    var primaryText: Color { Color(red: 0.88, green: 0.88, blue: 1.0) }
    var secondaryText: Color { Color(red: 0.376, green: 0.376, blue: 0.627) }
    var tertiaryText: Color { Color(red: 0.251, green: 0.251, blue: 0.439) }

    var sidebarHover: Color { Color(red: 0.10, green: 0.10, blue: 0.18) }
    var sidebarActive: Color { Color(red: 0.12, green: 0.12, blue: 0.21) }
    var tableRowHover: Color { Color(red: 0.39, green: 0.39, blue: 1.0).opacity(0.06) }

    var trackBackground: Color { Color(red: 0.10, green: 0.10, blue: 0.18) }

    var glowEnabled: Bool { true }

    func accent(for category: MetricCategory) -> Color {
        switch category {
        case .overview: return Color(red: 0.0, green: 0.75, blue: 1.0)
        case .cpu: return Color(red: 0.0, green: 0.75, blue: 1.0)         // #00BFFF
        case .memory: return Color(red: 0.75, green: 0.25, blue: 1.0)     // #BF40FF
        case .disk: return Color(red: 0.22, green: 1.0, blue: 0.08)       // #39FF14
        case .network: return Color(red: 1.0, green: 0.4, blue: 0.0)      // #FF6600
        case .gpu: return Color(red: 0.0, green: 1.0, blue: 0.835)        // #00FFD5
        case .thermal: return Color(red: 1.0, green: 0.2, blue: 0.2)      // #FF3333
        case .processes: return Color(red: 0.565, green: 0.565, blue: 1.0) // #9090FF
        case .storage: return Color(red: 0.5, green: 0.4, blue: 1.0)      // #8066FF
        }
    }
}
