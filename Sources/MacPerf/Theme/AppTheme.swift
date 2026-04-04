import SwiftUI

extension Color {
    init(hex: UInt, opacity: Double = 1.0) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255,
            opacity: opacity
        )
    }
}

protocol AppTheme {
    var name: String { get }

    // Backgrounds
    var windowBackground: Color { get }
    var sidebarBackground: Color { get }
    var cardBackground: Color { get }
    var graphBackground: Color { get }

    // Borders & dividers
    var border: Color { get }
    var gridLine: Color { get }

    // Text
    var primaryText: Color { get }
    var secondaryText: Color { get }
    var tertiaryText: Color { get }

    // Interactive
    var sidebarHover: Color { get }
    var sidebarActive: Color { get }
    var tableRowHover: Color { get }

    // Tracks (core bars, gauge backgrounds)
    var trackBackground: Color { get }

    // Per-category accents
    func accent(for category: MetricCategory) -> Color
    func accentDim(for category: MetricCategory) -> Color

    // Special
    var glowEnabled: Bool { get }
    var cardShadow: Bool { get }
}

extension AppTheme {
    func accentDim(for category: MetricCategory) -> Color {
        accent(for: category).opacity(0.15)
    }

    var glowEnabled: Bool { false }
    var cardShadow: Bool { false }
}
