import SwiftUI

struct BatteryDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    private let statsColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: .battery)
        let battery = appState.batteryVM

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MetricHeader(
                    category: .battery,
                    value: "\(Int(battery.currentPercent))%",
                    timeRange: $appState.selectedTimeRange
                )

                // Charge history graph
                NeonChartView(
                    series: battery.chargeSeries,
                    color: accent,
                    maxValue: 100,
                    timeRange: appState.selectedTimeRange,
                    category: .battery,
                    sizeVariant: .full
                )
                .frame(height: 240)

                // Charging status card
                chargingStatusCard(theme: theme, battery: battery)

                // Stats grid
                LazyVGrid(columns: statsColumns, spacing: 12) {
                    StatCard(
                        title: "Charge",
                        value: "\(Int(battery.currentPercent))%",
                        valueColor: accent
                    )
                    StatCard(
                        title: "Health",
                        value: "\(Int(battery.healthPercent))%",
                        valueColor: battery.healthPercent > 80 ? accent : .orange
                    )
                    StatCard(
                        title: "Cycle Count",
                        value: "\(battery.cycleCount)",
                        valueColor: accent
                    )
                    StatCard(
                        title: "Temperature",
                        value: Formatters.formatTemperature(battery.temperature),
                        valueColor: battery.temperature > 40 ? .orange : theme.primaryText
                    )
                    StatCard(
                        title: "Voltage",
                        value: String(format: "%.2f V", battery.voltage),
                        valueColor: theme.primaryText
                    )
                    StatCard(
                        title: "Power",
                        value: formatPower(voltage: battery.voltage, amperage: battery.amperage),
                        valueColor: battery.isCharging ? accent : theme.accent(for: .network)
                    )
                }

                // Capacity info
                capacitySection(theme: theme, battery: battery, accent: accent)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 28)
        }
    }

    @ViewBuilder
    private func chargingStatusCard(theme: any AppTheme, battery: BatteryViewModel) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(statusColor(battery))
                .frame(width: 10, height: 10)

            Text(statusText(battery))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.primaryText)

            Spacer()

            if battery.timeRemaining > 0 && !battery.isPluggedIn {
                Text(formatTimeRemaining(battery.timeRemaining))
                    .font(.system(size: 13, weight: .medium).monospacedDigit())
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(theme.cardBackground))
    }

    @ViewBuilder
    private func capacitySection(theme: any AppTheme, battery: BatteryViewModel, accent: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Battery Health")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(theme.primaryText)

            // Health bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(theme.graphBackground)

                    RoundedRectangle(cornerRadius: 4)
                        .fill(accent)
                        .frame(width: geo.size.width * battery.healthPercent / 100)
                }
            }
            .frame(height: 8)

            HStack {
                Text("Design: \(battery.designCapacity) mAh")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.tertiaryText)
                Spacer()
                Text("Current Max: \(battery.maxCapacity) mAh")
                    .font(.system(size: 11))
                    .foregroundStyle(theme.secondaryText)
            }
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 10).fill(theme.cardBackground))
    }

    // MARK: - Helpers

    private func statusColor(_ battery: BatteryViewModel) -> Color {
        if battery.isCharging { return .green }
        if battery.isPluggedIn { return .blue }
        if battery.currentPercent < 20 { return .red }
        return .orange
    }

    private func statusText(_ battery: BatteryViewModel) -> String {
        if battery.isCharging { return "Charging" }
        if battery.isPluggedIn { return "Plugged In — Full" }
        return "On Battery"
    }

    private func formatTimeRemaining(_ minutes: Int) -> String {
        let h = minutes / 60
        let m = minutes % 60
        return h > 0 ? "\(h)h \(m)m remaining" : "\(m)m remaining"
    }

    private func formatPower(voltage: Double, amperage: Double) -> String {
        let watts = abs(voltage * amperage / 1000.0)
        return String(format: "%.1f W", watts)
    }
}
