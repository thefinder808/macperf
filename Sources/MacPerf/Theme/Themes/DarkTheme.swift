import SwiftUI

struct DarkTheme: AppTheme {
    let name = "Dark"

    var windowBackground: Color { Color(red: 0.10, green: 0.10, blue: 0.12) }
    var sidebarBackground: Color { Color(red: 0.145, green: 0.145, blue: 0.157) }
    var cardBackground: Color { Color(red: 0.145, green: 0.145, blue: 0.157) }
    var graphBackground: Color { Color(red: 0.145, green: 0.145, blue: 0.157) }

    var border: Color { Color(red: 0.227, green: 0.227, blue: 0.235) }
    var gridLine: Color { Color(red: 0.227, green: 0.227, blue: 0.235) }

    var primaryText: Color { Color(red: 0.898, green: 0.898, blue: 0.918) }
    var secondaryText: Color { Color(red: 0.557, green: 0.557, blue: 0.576) }
    var tertiaryText: Color { Color(red: 0.388, green: 0.388, blue: 0.400) }

    var sidebarHover: Color { Color(red: 0.227, green: 0.227, blue: 0.235) }
    var sidebarActive: Color { Color(red: 0.227, green: 0.227, blue: 0.235) }
    var tableRowHover: Color { Color.white.opacity(0.04) }

    var trackBackground: Color { Color(red: 0.227, green: 0.227, blue: 0.235) }

    func accent(for category: MetricCategory) -> Color {
        switch category {
        case .overview: return Color(red: 0.29, green: 0.56, blue: 0.85)
        case .cpu: return Color(red: 0.29, green: 0.56, blue: 0.85)       // #4A90D9
        case .memory: return Color(red: 0.61, green: 0.35, blue: 0.71)    // #9B59B6
        case .disk: return Color(red: 0.15, green: 0.68, blue: 0.38)      // #27AE60
        case .network: return Color(red: 0.90, green: 0.49, blue: 0.13)   // #E67E22
        case .gpu: return Color(red: 0.10, green: 0.74, blue: 0.61)       // #1ABC9C
        case .thermal: return Color(red: 0.91, green: 0.30, blue: 0.24)   // #E74C3C
        case .battery: return Color(red: 0.20, green: 0.78, blue: 0.35)   // #34C759
        case .processes: return Color(red: 0.557, green: 0.557, blue: 0.576) // #8E8E93
        case .storage: return Color(red: 0.345, green: 0.337, blue: 0.839) // #5856D6
        }
    }
}
