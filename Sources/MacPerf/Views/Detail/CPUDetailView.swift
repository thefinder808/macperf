import SwiftUI

struct CPUDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    private let statsColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: .cpu)
        let cpu = appState.cpuVM

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                MetricHeader(
                    category: .cpu,
                    value: Formatters.formatPercentage(cpu.overallUsage, decimals: 1),
                    timeRange: $appState.selectedTimeRange
                )

                // Main graph
                PerformanceGraph(
                    series: cpu.overallSeries,
                    color: accent,
                    maxValue: 100,
                    timeRange: appState.selectedTimeRange
                )
                .frame(height: 240)

                // Stats grid
                LazyVGrid(columns: statsColumns, spacing: 12) {
                    StatCard(
                        title: "User",
                        value: Formatters.formatPercentage(cpu.userUsage),
                        valueColor: accent,
                        progress: cpu.userUsage
                    )
                    StatCard(
                        title: "System",
                        value: Formatters.formatPercentage(cpu.systemUsage),
                        valueColor: accent,
                        progress: cpu.systemUsage
                    )
                    StatCard(
                        title: "Idle",
                        value: Formatters.formatPercentage(cpu.idleUsage)
                    )
                    StatCard(
                        title: "Processor",
                        value: appState.systemInfo.cpuModel
                    )
                    StatCard(
                        title: "Cores",
                        value: "\(appState.systemInfo.totalCores)",
                        subtitle: appState.systemInfo.coreDescription
                    )
                    StatCard(
                        title: "Peak",
                        value: Formatters.formatPercentage(cpu.overallSeries.peakValue),
                        subtitle: "Session maximum"
                    )
                }

                // Per-core grid
                perCoreSection(theme: theme, accent: accent, usages: cpu.perCoreUsages)
            }
            .padding(28)
        }
    }

    @ViewBuilder
    private func perCoreSection(theme: any AppTheme, accent: Color, usages: [Double]) -> some View {
        if !usages.isEmpty {
            VStack(alignment: .leading, spacing: 12) {
                Text("Per Core Usage")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.secondaryText)
                    .tracking(0.5)
                    .textCase(.uppercase)

                let pCores = appState.systemInfo.performanceCores
                let eCores = appState.systemInfo.efficiencyCores
                let coreColumns = Array(repeating: GridItem(.flexible(), spacing: 6), count: min(usages.count, 18))

                LazyVGrid(columns: coreColumns, spacing: 6) {
                    ForEach(Array(usages.enumerated()), id: \.offset) { index, usage in
                        CoreBarView(
                            usage: usage,
                            label: coreLabel(index: index, pCores: pCores, eCores: eCores),
                            accent: accent,
                            theme: theme
                        )
                    }
                }
            }
        }
    }

    private func coreLabel(index: Int, pCores: Int, eCores: Int) -> String {
        if pCores > 0 && eCores > 0 {
            return index < pCores ? "P\(index)" : "E\(index - pCores)"
        }
        return "\(index)"
    }
}

private struct CoreBarView: View {
    let usage: Double
    let label: String
    let accent: Color
    let theme: any AppTheme

    @State private var isHovered = false

    var body: some View {
        VStack(spacing: 4) {
            ZStack(alignment: .bottom) {
                RoundedRectangle(cornerRadius: 4)
                    .fill(theme.trackBackground)
                    .frame(height: 48)

                RoundedRectangle(cornerRadius: 4)
                    .fill(accent.opacity(0.3 + (usage / 100) * 0.7))
                    .frame(height: max(2, 48 * usage / 100))
                    .shadow(
                        color: theme.glowEnabled ? accent.opacity(0.5) : .clear,
                        radius: 4
                    )
                    .animation(.spring(response: 0.5, dampingFraction: 0.6), value: usage)

                // Percentage label overlay for bars > 30%
                if usage > 30 {
                    Text("\(Int(usage))%")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(.white)
                        .transition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: usage > 30)
                }
            }
            .frame(height: 48)
            .scaleEffect(x: isHovered ? 1.1 : 1.0, y: 1.0)
            .animation(.spring(response: 0.3), value: isHovered)

            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(theme.tertiaryText)
        }
        .onHover { hovering in
            isHovered = hovering
        }
        .help(isHovered ? "\(label): \(String(format: "%.1f", usage))%" : "")
    }
}
