import Foundation

enum ChartType: String, CaseIterable, Codable, Identifiable {
    case area
    case bar

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .area: return "chart.xyaxis.line"
        case .bar: return "chart.bar.fill"
        }
    }

    var label: String {
        switch self {
        case .area: return "Area"
        case .bar: return "Bar"
        }
    }
}

enum ChartSizeVariant {
    case compact   // ~60x24pt — menu bar, sidebar sparklines
    case medium    // ~200x120pt — dashboard cards (Phase 3)
    case full      // fills width, ~200pt tall — detail views
}
