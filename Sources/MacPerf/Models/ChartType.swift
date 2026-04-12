import Foundation

enum ChartType: String, CaseIterable, Codable, Identifiable {
    case line
    case bar
    case area

    var id: String { rawValue }

    var systemImage: String {
        switch self {
        case .line: return "chart.line.uptrend.xyaxis"
        case .bar: return "chart.bar.fill"
        case .area: return "chart.xyaxis.line"
        }
    }

    var label: String {
        switch self {
        case .line: return "Line"
        case .bar: return "Bar"
        case .area: return "Area"
        }
    }
}

enum ChartSizeVariant {
    case compact   // ~60x24pt — menu bar, sidebar sparklines
    case medium    // ~200x120pt — dashboard cards (Phase 3)
    case full      // fills width, ~200pt tall — detail views
}
