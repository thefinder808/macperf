import SwiftUI
import Charts

struct NeonChartView: View {
    @ObservedObject var series: TimeSeries
    let color: Color
    let maxValue: Double
    let timeRange: TimeRange
    let category: MetricCategory
    let sizeVariant: ChartSizeVariant

    var secondarySeries: TimeSeries?
    var secondaryColor: Color?

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager
    @State private var scrubIndex: Int?

    var body: some View {
        let theme = themeManager.current
        let chartType = settingsManager.chartType

        switch sizeVariant {
        case .compact:
            compactChart(theme: theme, chartType: chartType)
        case .medium, .full:
            fullChart(theme: theme, chartType: chartType)
        }
    }

    // MARK: - Compact Variant (sparkline replacement)

    @ViewBuilder
    private func compactChart(theme: any AppTheme, chartType: ChartType) -> some View {
        let points = indexedPoints(from: series, range: .oneMinute)
        let gradientColors = theme.chartGradientColors(for: category)
        let glowRadius = theme.chartGlowRadius

        Chart {
            ForEach(points, id: \.index) { point in
                switch chartType {
                case .bar:
                    BarMark(
                        x: .value("Time", point.index),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [gradientColors.start, gradientColors.end],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )
                case .area:
                    AreaMark(
                        x: .value("Time", point.index),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [color.opacity(0.3), color.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", point.index),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1))
                    .interpolationMethod(.catmullRom)
                }
            }
        }
        .chartXScale(domain: 0...60)
        .chartYScale(domain: 0...compactMaxValue(points: points))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        // Live sparklines aren't VoiceOver-navigable; opting out skips Swift Charts'
        // per-redraw accessibility-data generation (a real cost at 1 Hz updates).
        .accessibilityHidden(true)
        .shadow(color: glowRadius > 0 ? color.opacity(0.4) : .clear, radius: glowRadius / 2)
    }

    // MARK: - Full Variant (detail view replacement)

    @ViewBuilder
    private func fullChart(theme: any AppTheme, chartType: ChartType) -> some View {
        let points = indexedPoints(from: series, range: timeRange)
        let secondaryPoints = secondarySeries.map { indexedPoints(from: $0, range: timeRange) } ?? []
        let peakPoint = points.max(by: { $0.value < $1.value })
        let gradientColors = theme.chartGradientColors(for: category)
        let glowRadius = theme.chartGlowRadius

        Chart {
            // Primary series
            ForEach(points, id: \.index) { point in
                switch chartType {
                case .bar:
                    BarMark(
                        x: .value("Time", point.index),
                        y: .value("Value", point.value),
                        width: 2
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [gradientColors.start, gradientColors.end],
                            startPoint: .bottom,
                            endPoint: .top
                        )
                    )

                case .area:
                    AreaMark(
                        x: .value("Time", point.index),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(
                        .linearGradient(
                            colors: [gradientColors.start.opacity(0.4), gradientColors.end.opacity(0.05)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                    .interpolationMethod(.catmullRom)

                    LineMark(
                        x: .value("Time", point.index),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }

            // Secondary series (dual-line graphs: disk read/write, network up/down, thermal CPU/GPU)
            if !secondaryPoints.isEmpty, let secColor = secondaryColor {
                ForEach(secondaryPoints, id: \.index) { point in
                    switch chartType {
                    case .area:
                        LineMark(
                            x: .value("Time", point.index),
                            y: .value("Value", point.value),
                            series: .value("Series", "secondary")
                        )
                        .foregroundStyle(secColor)
                        .lineStyle(StrokeStyle(lineWidth: 2))
                        .interpolationMethod(.catmullRom)
                    case .bar:
                        BarMark(
                            x: .value("Time", point.index),
                            y: .value("Value", point.value),
                            width: 2
                        )
                        .foregroundStyle(secColor.opacity(0.6))
                    }
                }
            }

            // Peak marker (not shown for bar charts -- clutters the bars)
            if chartType != .bar, let peak = peakPoint, peak.value > 0 {
                PointMark(
                    x: .value("Time", peak.index),
                    y: .value("Value", peak.value)
                )
                .symbol {
                    Rectangle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .rotationEffect(.degrees(45))
                        .shadow(color: glowRadius > 0 ? color.opacity(0.8) : .clear, radius: glowRadius)
                }

                RuleMark(y: .value("Peak", peak.value))
                    .foregroundStyle(color.opacity(0.3))
                    .lineStyle(StrokeStyle(lineWidth: 0.5, dash: [4, 4]))
            }

            // Scrub rule line
            if let idx = scrubIndex {
                RuleMark(x: .value("Scrub", idx))
                    .foregroundStyle(color.opacity(0.5))
                    .lineStyle(StrokeStyle(lineWidth: 1))
            }
        }
        .chartXScale(domain: 0...timeRange.seconds)
        .chartYScale(domain: 0...effectiveMax(points: points, secondary: secondaryPoints))
        .chartXAxis(.hidden)
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 5)) { value in
                AxisGridLine()
                    .foregroundStyle(theme.gridLine)
                AxisValueLabel()
                    .foregroundStyle(theme.tertiaryText)
            }
        }
        .chartPlotStyle { plotArea in
            plotArea
                .background(theme.graphBackground.opacity(0.5))
                .border(theme.border.opacity(0.3), width: 0)
        }
        .chartOverlay { proxy in
            GeometryReader { geometry in
                Rectangle()
                    .fill(.clear)
                    .contentShape(Rectangle())
                    .gesture(
                        DragGesture(minimumDistance: 0)
                            .onChanged { drag in
                                let origin = geometry[proxy.plotFrame!].origin
                                let localX = drag.location.x - origin.x
                                if let idx: Int = proxy.value(atX: localX) {
                                    scrubIndex = idx
                                }
                            }
                            .onEnded { _ in
                                scrubIndex = nil
                            }
                    )
                    .onHover { hovering in
                        if !hovering {
                            scrubIndex = nil
                        }
                    }

                // Tooltip bubble
                if let idx = scrubIndex,
                   let matchingPoint = points.first(where: { $0.index == idx }) ?? points.min(by: { abs($0.index - idx) < abs($1.index - idx) }) {
                    let origin = geometry[proxy.plotFrame!].origin
                    let plotSize = geometry[proxy.plotFrame!].size
                    let effMax = effectiveMax(points: points, secondary: secondaryPoints)
                    let xPos = origin.x + plotSize.width * CGFloat(idx) / CGFloat(timeRange.seconds)
                    let yPos = origin.y + plotSize.height * (1.0 - matchingPoint.value / effMax)
                    let secsAgo = timeRange.seconds - idx

                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatScrubValue(matchingPoint.value))
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundStyle(color)
                        Text(formatTimeAgo(secsAgo))
                            .font(.system(size: 10))
                            .foregroundStyle(theme.tertiaryText)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(theme.cardBackground)
                            .shadow(color: .black.opacity(0.3), radius: 6, y: 2)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(theme.border, lineWidth: 1)
                    )
                    .position(
                        x: min(max(xPos, 40), geometry.size.width - 40),
                        y: max(yPos - 30, 20)
                    )
                    .allowsHitTesting(false)
                    .animation(.interactiveSpring(), value: scrubIndex)
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.graphBackground)
                .shadow(color: theme.cardShadow ? .black.opacity(0.06) : .clear, radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.cardShadow ? .clear : theme.border, lineWidth: 1)
        )
        .shadow(color: glowRadius > 0 ? color.opacity(0.15) : .clear, radius: glowRadius)
        .animation(.easeInOut(duration: 0.3), value: chartType)
        .accessibilityHidden(true)
    }

    // MARK: - Helpers

    private func compactMaxValue(points: [IndexedPoint]) -> Double {
        if maxValue > 0 { return maxValue }
        let peak = points.map(\.value).max() ?? 1
        return max(peak * 1.2, 1)
    }

    private func effectiveMax(points: [IndexedPoint], secondary: [IndexedPoint]) -> Double {
        if maxValue > 0 { return maxValue }
        let allValues = points.map(\.value) + secondary.map(\.value)
        let peak = allValues.max() ?? 1
        return max(peak * 1.2, 1)
    }

    private func formatScrubValue(_ value: Double) -> String {
        if maxValue == 100 {
            return String(format: "%.1f%%", value)
        }
        return Formatters.formatBytesPerSec(value)
    }

    private func formatTimeAgo(_ seconds: Int) -> String {
        if seconds < 60 {
            return "\(seconds)s ago"
        } else {
            return "\(seconds / 60)m \(seconds % 60)s ago"
        }
    }
}

// MARK: - Shared types

struct IndexedPoint {
    let index: Int
    let value: Double
}

func indexedPoints(from series: TimeSeries, range: TimeRange) -> [IndexedPoint] {
    let points = series.points(for: range)
    let total = range.seconds
    let offset = total - points.count
    return points.enumerated().map { i, point in
        IndexedPoint(index: offset + i, value: point.value)
    }
}
