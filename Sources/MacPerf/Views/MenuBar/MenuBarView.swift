import SwiftUI

struct MenuBarView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header
            HStack {
                Text("MacPerf")
                    .font(.system(size: 13, weight: .bold))
                Spacer()
                Text("Live")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.green)
            }

            Divider()

            // CPU
            menuBarRow(
                icon: "cpu",
                label: "CPU",
                value: Formatters.formatPercentage(appState.cpuUsage, decimals: 1),
                series: appState.cpuSeries,
                color: .blue
            )

            // Memory
            menuBarRow(
                icon: "memorychip",
                label: "Memory",
                value: Formatters.formatPercentage(appState.memoryUsage, decimals: 1),
                series: appState.memorySeries,
                color: .purple
            )

            // GPU
            menuBarRow(
                icon: "rectangle.3.group",
                label: "GPU",
                value: Formatters.formatPercentage(appState.gpuUsage, decimals: 1),
                series: appState.gpuSeries,
                color: .teal
            )

            // Disk
            menuBarRow(
                icon: "internaldrive",
                label: "Disk",
                value: Formatters.formatBytesPerSec(appState.diskReadRate),
                series: appState.diskReadSeries,
                color: .green
            )

            // Network
            menuBarRow(
                icon: "network",
                label: "Network",
                value: Formatters.formatBytesPerSec(appState.networkDownRate),
                series: appState.networkDownSeries,
                color: .orange
            )

            // Thermal
            menuBarRow(
                icon: "thermometer.medium",
                label: "Thermal",
                value: Formatters.formatTemperature(appState.thermalTemp),
                series: appState.thermalSeries,
                color: .red
            )

            Divider()

            // Quick stats
            HStack {
                Text("Processes: \(appState.processVM.processCount)")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Threads: \(Formatters.formatCount(appState.processVM.totalThreads))")
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(12)
        .frame(width: 280)
    }

    @ViewBuilder
    private func menuBarRow(icon: String, label: String, value: String, series: TimeSeries, color: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 11))
                .foregroundStyle(color)
                .frame(width: 16)

            Text(label)
                .font(.system(size: 12))
                .frame(width: 55, alignment: .leading)

            MiniSparkline(series: series, color: color, pointCount: 30)
                .frame(width: 50, height: 16)

            Spacer()

            Text(value)
                .font(.system(size: 12, weight: .semibold).monospacedDigit())
                .foregroundStyle(color)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: value)
        }
    }
}
