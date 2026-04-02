import SwiftUI

struct MemoryDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    private let statsColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: .memory)
        let mem = appState.memoryVM

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                MetricHeader(
                    category: .memory,
                    value: Formatters.formatPercentage(mem.pressurePercent, decimals: 1),
                    timeRange: $appState.selectedTimeRange
                )

                // Main graph — memory pressure over time
                PerformanceGraph(
                    series: mem.pressureSeries,
                    color: accent,
                    maxValue: 100,
                    timeRange: appState.selectedTimeRange
                )
                .frame(height: 240)

                // Pressure gauge + description
                pressureSection(theme: theme, mem: mem)

                // Stats grid
                LazyVGrid(columns: statsColumns, spacing: 12) {
                    StatCard(
                        title: "Used",
                        value: Formatters.formatBytes(mem.usedBytes),
                        valueColor: accent
                    )
                    StatCard(
                        title: "App Memory",
                        value: Formatters.formatBytes(mem.appBytes),
                        valueColor: accent
                    )
                    StatCard(
                        title: "Wired",
                        value: Formatters.formatBytes(mem.wiredBytes)
                    )
                    StatCard(
                        title: "Compressed",
                        value: Formatters.formatBytes(mem.compressedBytes)
                    )
                    StatCard(
                        title: "Cached",
                        value: Formatters.formatBytes(mem.cachedBytes)
                    )
                    StatCard(
                        title: "Free",
                        value: Formatters.formatBytes(mem.freeBytes)
                    )
                    StatCard(
                        title: "Swap Used",
                        value: Formatters.formatBytes(mem.swapUsedBytes)
                    )
                    StatCard(
                        title: "Total RAM",
                        value: Formatters.formatBytes(mem.totalBytes)
                    )
                }

                // Memory composition bar
                compositionSection(theme: theme, accent: accent, mem: mem)
            }
            .padding(28)
        }
    }

    @ViewBuilder
    private func pressureSection(theme: any AppTheme, mem: MemoryViewModel) -> some View {
        HStack(alignment: .top, spacing: 24) {
            PressureGauge(
                value: mem.pressurePercent,
                level: mem.pressureLevel
            )
            .frame(width: 140, height: 90)

            VStack(alignment: .leading, spacing: 6) {
                Text("Memory Pressure")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .tracking(0.5)
                    .textCase(.uppercase)

                Text(pressureDescription(for: mem.pressureLevel))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.tertiaryText)
                    .lineSpacing(4)
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(theme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func compositionSection(theme: any AppTheme, accent: Color, mem: MemoryViewModel) -> some View {
        let total = max(Double(mem.totalBytes), 1)
        let segments: [(String, Double, Color)] = [
            ("App", Double(mem.appBytes) / total, accent),
            ("Wired", Double(mem.wiredBytes) / total, accent.opacity(0.7)),
            ("Compressed", Double(mem.compressedBytes) / total, accent.opacity(0.5)),
            ("Cached", Double(mem.cachedBytes) / total, accent.opacity(0.25)),
            ("Free", Double(mem.freeBytes) / total, theme.trackBackground),
        ]

        VStack(alignment: .leading, spacing: 12) {
            Text("Memory Composition")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
                .tracking(0.5)
                .textCase(.uppercase)

            // Bar
            GeometryReader { geo in
                HStack(spacing: 2) {
                    ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                        let (_, fraction, color) = segment
                        RoundedRectangle(cornerRadius: 3)
                            .fill(color)
                            .frame(width: max(2, geo.size.width * fraction))
                    }
                }
            }
            .frame(height: 24)
            .clipShape(RoundedRectangle(cornerRadius: 6))

            // Legend
            HStack(spacing: 16) {
                ForEach(Array(segments.enumerated()), id: \.offset) { _, segment in
                    let (name, _, color) = segment
                    HStack(spacing: 6) {
                        RoundedRectangle(cornerRadius: 2)
                            .fill(color)
                            .frame(width: 8, height: 8)
                        Text(name)
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondaryText)
                    }
                }
            }
        }
    }

    private func pressureDescription(for level: MemoryMonitor.PressureLevel) -> String {
        switch level {
        case .normal:
            return "System memory resources are available. The system is not under memory pressure."
        case .warning:
            return "System memory resources are becoming constrained. The system may begin compressing memory to free up space."
        case .critical:
            return "System memory resources are critically low. The system is actively swapping and may become unresponsive."
        }
    }
}
