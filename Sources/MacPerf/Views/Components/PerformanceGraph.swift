import SwiftUI
import Charts

struct PerformanceGraph: View {
    @ObservedObject var series: TimeSeries
    let color: Color
    let maxValue: Double
    let timeRange: TimeRange

    var secondarySeries: TimeSeries?
    var secondaryColor: Color?

    @EnvironmentObject var themeManager: ThemeManager
    @State private var scrubIndex: Int?

    var body: some View {
        let theme = themeManager.current
        let points = indexedPoints(from: series, range: timeRange)
        let secondaryPoints = secondarySeries.map { indexedPoints(from: $0, range: timeRange) } ?? []
        let peakPoint = points.max(by: { $0.value < $1.value })

        Chart {
            // Primary series
            ForEach(points, id: \.index) { point in
                AreaMark(
                    x: .value("Time", point.index),
                    y: .value("Value", point.value)
                )
                .foregroundStyle(
                    .linearGradient(
                        colors: [color.opacity(0.2), color.opacity(0.0)],
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

            // Secondary series (for dual-line graphs like disk read/write)
            if !secondaryPoints.isEmpty, let secColor = secondaryColor {
                ForEach(secondaryPoints, id: \.index) { point in
                    LineMark(
                        x: .value("Time", point.index),
                        y: .value("Value", point.value),
                        series: .value("Series", "secondary")
                    )
                    .foregroundStyle(secColor)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .interpolationMethod(.catmullRom)
                }
            }

            // Peak marker
            if let peak = peakPoint, peak.value > 0 {
                PointMark(
                    x: .value("Time", peak.index),
                    y: .value("Value", peak.value)
                )
                .symbol {
                    Rectangle()
                        .fill(color)
                        .frame(width: 6, height: 6)
                        .rotationEffect(.degrees(45))
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
    }

    private func effectiveMax(points: [IndexedPoint], secondary: [IndexedPoint]) -> Double {
        if maxValue > 0 { return maxValue }
        // Auto-scale for non-percentage graphs
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
