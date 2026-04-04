import SwiftUI

struct ThermalDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    private let statsColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: .thermal)
        let thermal = appState.thermalVM

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MetricHeader(
                    category: .thermal,
                    value: Formatters.formatTemperature(thermal.cpuTemperature),
                    timeRange: $appState.selectedTimeRange
                )

                // Legend
                HStack(spacing: 20) {
                    legendItem(color: accent, label: "CPU Temperature")
                    legendItem(color: accent.opacity(0.5), label: "GPU Temperature")
                }

                // Dual-line temp graph
                PerformanceGraph(
                    series: thermal.cpuTempSeries,
                    color: accent,
                    maxValue: 110,
                    timeRange: appState.selectedTimeRange,
                    secondarySeries: thermal.gpuTempSeries,
                    secondaryColor: accent.opacity(0.5)
                )
                .frame(height: 240)

                // Thermal state indicator
                thermalStateCard(theme: theme, thermal: thermal)

                // Stats
                LazyVGrid(columns: statsColumns, spacing: 12) {
                    StatCard(
                        title: "CPU Temp",
                        value: Formatters.formatTemperature(thermal.cpuTemperature),
                        valueColor: tempColor(thermal.cpuTemperature)
                    )
                    StatCard(
                        title: "GPU Temp",
                        value: Formatters.formatTemperature(thermal.gpuTemperature),
                        valueColor: tempColor(thermal.gpuTemperature)
                    )
                    StatCard(
                        title: "Thermal State",
                        value: thermal.thermalState.rawValue,
                        valueColor: stateColor(thermal.thermalState)
                    )
                    StatCard(
                        title: "CPU Peak",
                        value: Formatters.formatTemperature(thermal.cpuTempSeries.peakValue),
                        subtitle: "Session maximum"
                    )
                    StatCard(
                        title: "CPU Average",
                        value: Formatters.formatTemperature(thermal.cpuTempSeries.averageValue),
                        subtitle: "Session average"
                    )
                }

                // Fan speeds if available
                if !thermal.fanSpeeds.isEmpty {
                    fanSection(theme: theme, fans: thermal.fanSpeeds)
                }
            }
            .padding(32)
        }
    }

    @ViewBuilder
    private func thermalStateCard(theme: any AppTheme, thermal: ThermalViewModel) -> some View {
        let color = stateColor(thermal.thermalState)

        HStack(spacing: 16) {
            Circle()
                .fill(color)
                .frame(width: 12, height: 12)
                .shadow(color: theme.glowEnabled ? color.opacity(0.6) : .clear, radius: 6)

            VStack(alignment: .leading, spacing: 4) {
                Text("System Thermal State: \(thermal.thermalState.rawValue)")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(theme.primaryText)

                Text(stateDescription(thermal.thermalState))
                    .font(.system(size: 12))
                    .foregroundStyle(theme.tertiaryText)
            }

            Spacer()
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
    private func fanSection(theme: any AppTheme, fans: [ThermalMonitor.FanReading]) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Fan Speeds")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
                .tracking(0.5)
                .textCase(.uppercase)

            ForEach(Array(fans.enumerated()), id: \.offset) { _, fan in
                StatCard(
                    title: fan.name,
                    value: Formatters.formatRPM(fan.currentRPM),
                    subtitle: "\(Formatters.formatRPM(fan.minRPM)) – \(Formatters.formatRPM(fan.maxRPM))"
                )
            }
        }
    }

    private func tempColor(_ temp: Double) -> Color {
        if temp > 90 { return .red }
        if temp > 75 { return .orange }
        if temp > 60 { return .yellow }
        return .green
    }

    private func stateColor(_ state: ThermalMonitor.ThermalState) -> Color {
        switch state {
        case .nominal: return .green
        case .fair: return .yellow
        case .serious: return .orange
        case .critical: return .red
        }
    }

    private func stateDescription(_ state: ThermalMonitor.ThermalState) -> String {
        switch state {
        case .nominal: return "System is operating normally with no thermal constraints."
        case .fair: return "System is slightly warm. Performance may be slightly reduced."
        case .serious: return "System is hot. Performance is being actively throttled."
        case .critical: return "System is critically hot. Significant throttling in effect."
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2).fill(color).frame(width: 16, height: 3)
            Text(label).font(.system(size: 12)).foregroundStyle(themeManager.current.secondaryText)
        }
    }
}
