# Phase 1: Modular NeonChart System — Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace `PerformanceGraph` with a modular `NeonChartView` supporting user-configurable chart types (line, bar, area) and neon/cyberpunk styling across all themes.

**Architecture:** A new `NeonChartView` SwiftUI component replaces the existing `PerformanceGraph` and `MiniSparkline` views. It reads chart type preferences from `SettingsManager` and styling from the `AppTheme` protocol (extended with chart-specific color properties). A chart type selector in `MetricHeader` lets users toggle between line, bar, and area for each metric category.

**Tech Stack:** SwiftUI, Swift Charts, UserDefaults

---

## File Structure

| Action | File | Responsibility |
|--------|------|---------------|
| Create | `Sources/MacPerf/Models/ChartType.swift` | `ChartType` enum (.line, .bar, .area) and `ChartSizeVariant` enum (.compact, .medium, .full) |
| Create | `Sources/MacPerf/Views/Components/NeonChartView.swift` | Modular chart component supporting all chart types, dual series, scrubbing, and neon styling |
| Modify | `Sources/MacPerf/Theme/AppTheme.swift` | Add `chartGlowColor`, `chartGradientStart`, `chartGradientEnd` to protocol |
| Modify | `Sources/MacPerf/Theme/Themes/NeonTheme.swift` | Implement neon chart colors (cyan/magenta glows) |
| Modify | `Sources/MacPerf/Theme/Themes/DarkTheme.swift` | Implement subtle dark chart colors |
| Modify | `Sources/MacPerf/Theme/Themes/LightTheme.swift` | Implement light chart colors |
| Modify | `Sources/MacPerf/App/SettingsManager.swift` | Add per-metric `ChartType` persistence |
| Modify | `Sources/MacPerf/Views/Components/MetricHeader.swift` | Add chart type segmented picker |
| Modify | `Sources/MacPerf/Views/Detail/CPUDetailView.swift` | Replace `PerformanceGraph` with `NeonChartView` |
| Modify | `Sources/MacPerf/Views/Detail/MemoryDetailView.swift` | Replace both `PerformanceGraph` usages |
| Modify | `Sources/MacPerf/Views/Detail/GPUDetailView.swift` | Replace `PerformanceGraph` |
| Modify | `Sources/MacPerf/Views/Detail/NetworkDetailView.swift` | Replace dual-series `PerformanceGraph` |
| Modify | `Sources/MacPerf/Views/Detail/DiskDetailView.swift` | Replace dual-series `PerformanceGraph` |
| Modify | `Sources/MacPerf/Views/Detail/ThermalDetailView.swift` | Replace dual-series `PerformanceGraph` |
| Modify | `Sources/MacPerf/Views/Detail/BatteryDetailView.swift` | Replace `PerformanceGraph` |
| Modify | `Sources/MacPerf/Views/Components/MiniGraphCard.swift` | Replace `MiniSparkline` with `NeonChartView(.compact)` |
| Remove | `Sources/MacPerf/Views/Components/PerformanceGraph.swift` | Replaced by `NeonChartView` |
| Remove | `Sources/MacPerf/Views/Components/MiniSparkline.swift` | Replaced by `NeonChartView(.compact)` |

---

### Task 1: Create ChartType and ChartSizeVariant models

**Files:**
- Create: `Sources/MacPerf/Models/ChartType.swift`

- [ ] **Step 1: Create the ChartType model file**

```swift
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
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/thefinder808/Development/macperf && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/MacPerf/Models/ChartType.swift
git commit -m "feat: add ChartType and ChartSizeVariant models"
```

---

### Task 2: Extend AppTheme protocol with chart colors

**Files:**
- Modify: `Sources/MacPerf/Theme/AppTheme.swift` (add 3 new protocol requirements with defaults)
- Modify: `Sources/MacPerf/Theme/Themes/NeonTheme.swift` (neon glow colors)
- Modify: `Sources/MacPerf/Theme/Themes/DarkTheme.swift` (subtle dark colors)
- Modify: `Sources/MacPerf/Theme/Themes/LightTheme.swift` (light colors)

- [ ] **Step 1: Add chart color requirements to AppTheme protocol**

In `Sources/MacPerf/Theme/AppTheme.swift`, add these three new properties to the `protocol AppTheme` block, after the `func accentDim(for category: MetricCategory) -> Color` line:

```swift
    // Chart styling
    var chartGlowRadius: CGFloat { get }
    func chartGradientColors(for category: MetricCategory) -> (start: Color, end: Color)
```

Then add default implementations in the existing `extension AppTheme` block:

```swift
    var chartGlowRadius: CGFloat { 0 }

    func chartGradientColors(for category: MetricCategory) -> (start: Color, end: Color) {
        (accent(for: category), accent(for: category).opacity(0.5))
    }
```

- [ ] **Step 2: Implement neon chart colors in NeonTheme**

In `Sources/MacPerf/Theme/Themes/NeonTheme.swift`, add inside the `NeonTheme` struct, after the `accent(for:)` function:

```swift
    var chartGlowRadius: CGFloat { 8 }

    func chartGradientColors(for category: MetricCategory) -> (start: Color, end: Color) {
        let base = accent(for: category)
        return (base, Color(red: 1.0, green: 0.0, blue: 1.0)) // accent → magenta
    }
```

- [ ] **Step 3: Implement dark chart colors in DarkTheme**

In `Sources/MacPerf/Theme/Themes/DarkTheme.swift`, add inside the `DarkTheme` struct, after the `accent(for:)` function:

```swift
    var chartGlowRadius: CGFloat { 0 }

    func chartGradientColors(for category: MetricCategory) -> (start: Color, end: Color) {
        let base = accent(for: category)
        return (base, base.opacity(0.6))
    }
```

- [ ] **Step 4: Implement light chart colors in LightTheme**

In `Sources/MacPerf/Theme/Themes/LightTheme.swift`, add inside the `LightTheme` struct, after the `accent(for:)` function:

```swift
    var chartGlowRadius: CGFloat { 0 }

    func chartGradientColors(for category: MetricCategory) -> (start: Color, end: Color) {
        let base = accent(for: category)
        return (base, base.opacity(0.7))
    }
```

- [ ] **Step 5: Verify build**

Run: `cd /Users/thefinder808/Development/macperf && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 6: Commit**

```bash
git add Sources/MacPerf/Theme/AppTheme.swift Sources/MacPerf/Theme/Themes/NeonTheme.swift Sources/MacPerf/Theme/Themes/DarkTheme.swift Sources/MacPerf/Theme/Themes/LightTheme.swift
git commit -m "feat: extend AppTheme with chart-specific color properties"
```

---

### Task 3: Add chart type preferences to SettingsManager

**Files:**
- Modify: `Sources/MacPerf/App/SettingsManager.swift`

- [ ] **Step 1: Add chart type storage to SettingsManager**

In `Sources/MacPerf/App/SettingsManager.swift`, add a new static key after the existing `labelModeKey`:

```swift
    private static let chartTypesKey = "macperf.chartTypes"
```

Add a new published property after the `useTextLabels` property:

```swift
    @Published var chartTypes: [MetricCategory: ChartType] {
        didSet { saveChartTypes() }
    }
```

In the `init()` method, after the line `self.useTextLabels = UserDefaults.standard.bool(forKey: Self.labelModeKey)`, add:

```swift
        if let saved = UserDefaults.standard.dictionary(forKey: Self.chartTypesKey) as? [String: String] {
            var types: [MetricCategory: ChartType] = [:]
            for (key, value) in saved {
                if let category = MetricCategory(rawValue: key),
                   let chartType = ChartType(rawValue: value) {
                    types[category] = chartType
                }
            }
            self.chartTypes = types
        } else {
            self.chartTypes = [:]
        }
```

Add a new save method after the existing `save()` method:

```swift
    private func saveChartTypes() {
        let raw = Dictionary(uniqueKeysWithValues: chartTypes.map { ($0.key.rawValue, $0.value.rawValue) })
        UserDefaults.standard.set(raw, forKey: Self.chartTypesKey)
    }
```

Add a convenience accessor after `menuBarLabel(from:)`:

```swift
    func chartType(for category: MetricCategory) -> ChartType {
        chartTypes[category] ?? .line
    }
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/thefinder808/Development/macperf && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/MacPerf/App/SettingsManager.swift
git commit -m "feat: add per-metric chart type preferences to SettingsManager"
```

---

### Task 4: Create NeonChartView component

**Files:**
- Create: `Sources/MacPerf/Views/Components/NeonChartView.swift`

This is the core component. It must support everything `PerformanceGraph` does (single/dual series, scrubbing, peak markers, auto-scale) plus chart type switching and neon styling.

- [ ] **Step 1: Create NeonChartView.swift**

```swift
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
        let chartType = settingsManager.chartType(for: category)

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
                case .line:
                    LineMark(
                        x: .value("Time", point.index),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(color)
                    .lineStyle(StrokeStyle(lineWidth: 1.5))
                    .interpolationMethod(.catmullRom)
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
                case .line:
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
                    case .line, .area:
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
                            y: .value("Value", point.value)
                        )
                        .foregroundStyle(secColor.opacity(0.6))
                    }
                }
            }

            // Peak marker (not shown for bar charts — clutters the bars)
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

// MARK: - IndexedPoint (shared with legacy code during migration)

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
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/thefinder808/Development/macperf && swift build 2>&1 | tail -20`
Expected: May have duplicate `IndexedPoint` — if so, remove it from `PerformanceGraph.swift` in the next step. Otherwise build succeeds.

- [ ] **Step 3: If duplicate symbol error, remove IndexedPoint and indexedPoints from PerformanceGraph.swift**

In `Sources/MacPerf/Views/Components/PerformanceGraph.swift`, delete lines 200-212 (the `IndexedPoint` struct and `indexedPoints` function) since they now live in `NeonChartView.swift`. Then rebuild.

- [ ] **Step 4: Verify build succeeds**

Run: `cd /Users/thefinder808/Development/macperf && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 5: Commit**

```bash
git add Sources/MacPerf/Views/Components/NeonChartView.swift Sources/MacPerf/Views/Components/PerformanceGraph.swift
git commit -m "feat: create NeonChartView modular chart component"
```

---

### Task 5: Add chart type selector to MetricHeader

**Files:**
- Modify: `Sources/MacPerf/Views/Components/MetricHeader.swift`

- [ ] **Step 1: Add chart type picker to MetricHeader**

Replace the entire contents of `Sources/MacPerf/Views/Components/MetricHeader.swift` with:

```swift
import SwiftUI

struct MetricHeader: View {
    let category: MetricCategory
    let value: String
    @Binding var timeRange: TimeRange

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: category)
        let chartType = settingsManager.chartType(for: category)

        HStack(alignment: .center, spacing: 16) {
            Image(systemName: category.systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.accent(for: category).opacity(0.15))
                )

            Text(category.rawValue)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.primaryText)

            Spacer()

            // Chart type picker
            chartTypePicker(accent: accent, theme: theme, chartType: chartType)

            TimeRangePicker(selection: $timeRange)

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(accent)
                .shadow(color: theme.glowEnabled ? accent.opacity(0.6) : .clear, radius: 12)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: value)
        }
    }

    @ViewBuilder
    private func chartTypePicker(accent: Color, theme: any AppTheme, chartType: ChartType) -> some View {
        HStack(spacing: 2) {
            ForEach(ChartType.allCases) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        settingsManager.chartTypes[category] = type
                    }
                } label: {
                    Image(systemName: type.systemImage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(chartType == type ? accent : theme.tertiaryText)
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(chartType == type ? accent.opacity(0.15) : .clear)
                        )
                }
                .buttonStyle(.plain)
                .help(type.label)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(theme.border, lineWidth: 1)
        )
    }
}
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/thefinder808/Development/macperf && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/MacPerf/Views/Components/MetricHeader.swift
git commit -m "feat: add chart type picker to MetricHeader"
```

---

### Task 6: Integrate NeonChartView into all detail views

**Files:**
- Modify: `Sources/MacPerf/Views/Detail/CPUDetailView.swift`
- Modify: `Sources/MacPerf/Views/Detail/MemoryDetailView.swift`
- Modify: `Sources/MacPerf/Views/Detail/GPUDetailView.swift`
- Modify: `Sources/MacPerf/Views/Detail/NetworkDetailView.swift`
- Modify: `Sources/MacPerf/Views/Detail/DiskDetailView.swift`
- Modify: `Sources/MacPerf/Views/Detail/ThermalDetailView.swift`
- Modify: `Sources/MacPerf/Views/Detail/BatteryDetailView.swift`

Each view replaces its `PerformanceGraph(...)` call with `NeonChartView(...)`. The pattern is the same for each. The `NeonChartView` takes the same `series`, `color`, `maxValue`, and `timeRange` parameters, plus `category` and `sizeVariant: .full`.

- [ ] **Step 1: Update CPUDetailView**

In `Sources/MacPerf/Views/Detail/CPUDetailView.swift`, replace:

```swift
                PerformanceGraph(
                    series: cpu.overallSeries,
                    color: accent,
                    maxValue: 100,
                    timeRange: appState.selectedTimeRange
                )
                .frame(height: 240)
```

with:

```swift
                NeonChartView(
                    series: cpu.overallSeries,
                    color: accent,
                    maxValue: 100,
                    timeRange: appState.selectedTimeRange,
                    category: .cpu,
                    sizeVariant: .full
                )
                .frame(height: 240)
```

- [ ] **Step 2: Update MemoryDetailView**

In `Sources/MacPerf/Views/Detail/MemoryDetailView.swift`, replace the main graph:

```swift
                PerformanceGraph(
                    series: mem.usageSeries,
                    color: accent,
                    maxValue: 100,
                    timeRange: appState.selectedTimeRange
                )
                .frame(height: 240)
```

with:

```swift
                NeonChartView(
                    series: mem.usageSeries,
                    color: accent,
                    maxValue: 100,
                    timeRange: appState.selectedTimeRange,
                    category: .memory,
                    sizeVariant: .full
                )
                .frame(height: 240)
```

Also replace the pressure card graph inside `pressureCard`:

```swift
            PerformanceGraph(
                series: mem.pressureSeries,
                color: pressureColor,
                maxValue: 100,
                timeRange: appState.selectedTimeRange
            )
            .frame(height: 120)
```

with:

```swift
            NeonChartView(
                series: mem.pressureSeries,
                color: pressureColor,
                maxValue: 100,
                timeRange: appState.selectedTimeRange,
                category: .memory,
                sizeVariant: .full
            )
            .frame(height: 120)
```

- [ ] **Step 3: Update GPUDetailView**

In `Sources/MacPerf/Views/Detail/GPUDetailView.swift`, replace:

```swift
                PerformanceGraph(
                    series: gpu.deviceUtilSeries,
                    color: accent,
                    maxValue: 100,
                    timeRange: appState.selectedTimeRange
                )
                .frame(height: 240)
```

with:

```swift
                NeonChartView(
                    series: gpu.deviceUtilSeries,
                    color: accent,
                    maxValue: 100,
                    timeRange: appState.selectedTimeRange,
                    category: .gpu,
                    sizeVariant: .full
                )
                .frame(height: 240)
```

- [ ] **Step 4: Update NetworkDetailView**

In `Sources/MacPerf/Views/Detail/NetworkDetailView.swift`, replace:

```swift
                PerformanceGraph(
                    series: net.downloadSeries,
                    color: accent,
                    maxValue: 0, // auto-scale
                    timeRange: appState.selectedTimeRange,
                    secondarySeries: net.uploadSeries,
                    secondaryColor: accent.opacity(0.5)
                )
                .frame(height: 240)
```

with:

```swift
                NeonChartView(
                    series: net.downloadSeries,
                    color: accent,
                    maxValue: 0,
                    timeRange: appState.selectedTimeRange,
                    category: .network,
                    sizeVariant: .full,
                    secondarySeries: net.uploadSeries,
                    secondaryColor: accent.opacity(0.5)
                )
                .frame(height: 240)
```

- [ ] **Step 5: Update DiskDetailView**

In `Sources/MacPerf/Views/Detail/DiskDetailView.swift`, replace:

```swift
                PerformanceGraph(
                    series: disk.readSeries,
                    color: accent,
                    maxValue: 0, // auto-scale
                    timeRange: appState.selectedTimeRange,
                    secondarySeries: disk.writeSeries,
                    secondaryColor: accent.opacity(0.5)
                )
                .frame(height: 240)
```

with:

```swift
                NeonChartView(
                    series: disk.readSeries,
                    color: accent,
                    maxValue: 0,
                    timeRange: appState.selectedTimeRange,
                    category: .disk,
                    sizeVariant: .full,
                    secondarySeries: disk.writeSeries,
                    secondaryColor: accent.opacity(0.5)
                )
                .frame(height: 240)
```

- [ ] **Step 6: Update ThermalDetailView**

In `Sources/MacPerf/Views/Detail/ThermalDetailView.swift`, replace:

```swift
                PerformanceGraph(
                    series: thermal.cpuTempSeries,
                    color: accent,
                    maxValue: 110,
                    timeRange: appState.selectedTimeRange,
                    secondarySeries: thermal.gpuTempSeries,
                    secondaryColor: accent.opacity(0.5)
                )
                .frame(height: 240)
```

with:

```swift
                NeonChartView(
                    series: thermal.cpuTempSeries,
                    color: accent,
                    maxValue: 110,
                    timeRange: appState.selectedTimeRange,
                    category: .thermal,
                    sizeVariant: .full,
                    secondarySeries: thermal.gpuTempSeries,
                    secondaryColor: accent.opacity(0.5)
                )
                .frame(height: 240)
```

- [ ] **Step 7: Update BatteryDetailView**

In `Sources/MacPerf/Views/Detail/BatteryDetailView.swift`, replace:

```swift
                PerformanceGraph(
                    series: battery.chargeSeries,
                    color: accent,
                    maxValue: 100,
                    timeRange: appState.selectedTimeRange
                )
                .frame(height: 240)
```

with:

```swift
                NeonChartView(
                    series: battery.chargeSeries,
                    color: accent,
                    maxValue: 100,
                    timeRange: appState.selectedTimeRange,
                    category: .battery,
                    sizeVariant: .full
                )
                .frame(height: 240)
```

- [ ] **Step 8: Verify build**

Run: `cd /Users/thefinder808/Development/macperf && swift build 2>&1 | tail -10`
Expected: Build succeeds

- [ ] **Step 9: Commit**

```bash
git add Sources/MacPerf/Views/Detail/CPUDetailView.swift Sources/MacPerf/Views/Detail/MemoryDetailView.swift Sources/MacPerf/Views/Detail/GPUDetailView.swift Sources/MacPerf/Views/Detail/NetworkDetailView.swift Sources/MacPerf/Views/Detail/DiskDetailView.swift Sources/MacPerf/Views/Detail/ThermalDetailView.swift Sources/MacPerf/Views/Detail/BatteryDetailView.swift
git commit -m "feat: integrate NeonChartView into all detail views"
```

---

### Task 7: Update MiniGraphCard to use NeonChartView compact variant

**Files:**
- Modify: `Sources/MacPerf/Views/Components/MiniGraphCard.swift`

- [ ] **Step 1: Replace MiniSparkline with NeonChartView in MiniGraphCard**

In `Sources/MacPerf/Views/Components/MiniGraphCard.swift`, replace:

```swift
                MiniSparkline(series: series, color: accent, pointCount: 60)
                    .frame(height: 64)
```

with:

```swift
                NeonChartView(
                    series: series,
                    color: accent,
                    maxValue: 100,
                    timeRange: .oneMinute,
                    category: category,
                    sizeVariant: .compact
                )
                .frame(height: 64)
```

- [ ] **Step 2: Verify build**

Run: `cd /Users/thefinder808/Development/macperf && swift build 2>&1 | tail -5`
Expected: Build succeeds

- [ ] **Step 3: Commit**

```bash
git add Sources/MacPerf/Views/Components/MiniGraphCard.swift
git commit -m "feat: use NeonChartView compact variant in MiniGraphCard"
```

---

### Task 8: Remove legacy PerformanceGraph and MiniSparkline

**Files:**
- Remove: `Sources/MacPerf/Views/Components/PerformanceGraph.swift`
- Remove: `Sources/MacPerf/Views/Components/MiniSparkline.swift`

- [ ] **Step 1: Delete PerformanceGraph.swift**

Run: `rm Sources/MacPerf/Views/Components/PerformanceGraph.swift`

- [ ] **Step 2: Delete MiniSparkline.swift**

Run: `rm Sources/MacPerf/Views/Components/MiniSparkline.swift`

- [ ] **Step 3: Verify build**

Run: `cd /Users/thefinder808/Development/macperf && swift build 2>&1 | tail -10`
Expected: Build succeeds with no references to deleted files. If there are errors about missing types, check for any remaining references and fix them.

- [ ] **Step 4: Commit**

```bash
git add -A Sources/MacPerf/Views/Components/PerformanceGraph.swift Sources/MacPerf/Views/Components/MiniSparkline.swift
git commit -m "refactor: remove legacy PerformanceGraph and MiniSparkline"
```

---

### Task 9: Final verification

- [ ] **Step 1: Clean build**

Run: `cd /Users/thefinder808/Development/macperf && swift package clean && swift build 2>&1 | tail -10`
Expected: Clean build succeeds with no warnings related to our changes

- [ ] **Step 2: Run the app**

Run: `cd /Users/thefinder808/Development/macperf && swift run`

Verify visually:
1. Every detail view (CPU, Memory, GPU, Network, Disk, Thermal, Battery) shows the NeonChartView
2. Chart type selector appears in each MetricHeader — clicking line/bar/area toggles the chart style
3. Overview mini cards show compact sparklines
4. Switch themes (Cmd+T) — Neon theme has glow effects, Dark/Light themes are subtle
5. Quit and relaunch — chart type preferences persist
6. Time range picker (1m/5m/15m/1h) still works
7. Scrubbing tooltip works on full-size charts
