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

    var chartGlowRadius: CGFloat { 0 }

    func chartGradientColors(for category: MetricCategory) -> (start: Color, end: Color) {
        let base = accent(for: category)
        return (base, base.opacity(0.6))
    }

    func accent(for category: MetricCategory) -> Color {
        switch category {
        case .overview: return Color(hex: 0x0A84FF)
        case .cpu: return Color(hex: 0x0A84FF)       // Apple Blue (dark)
        case .memory: return Color(hex: 0xBF5AF2)     // Apple Purple (dark)
        case .disk: return Color(hex: 0x30D158)       // Apple Green (dark)
        case .network: return Color(hex: 0xFF9F0A)     // Apple Orange (dark)
        case .gpu: return Color(hex: 0x64D2FF)         // Apple Teal (dark)
        case .thermal: return Color(hex: 0xFF453A)     // Apple Red (dark)
        case .battery: return Color(hex: 0x30D158)     // Apple Green (dark)
        case .processes: return Color(hex: 0x98989D)   // Apple Gray (dark)
        case .storage: return Color(hex: 0x5E5CE6)     // Apple Indigo (dark)
        }
    }
}
