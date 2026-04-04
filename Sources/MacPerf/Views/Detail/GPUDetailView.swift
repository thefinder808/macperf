import SwiftUI

struct GPUDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    private let statsColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: .gpu)
        let gpu = appState.gpuVM

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MetricHeader(
                    category: .gpu,
                    value: Formatters.formatPercentage(gpu.deviceUtilization, decimals: 1),
                    timeRange: $appState.selectedTimeRange
                )

                PerformanceGraph(
                    series: gpu.deviceUtilSeries,
                    color: accent,
                    maxValue: 100,
                    timeRange: appState.selectedTimeRange
                )
                .frame(height: 240)

                LazyVGrid(columns: statsColumns, spacing: 12) {
                    StatCard(title: "Device", value: Formatters.formatPercentage(gpu.deviceUtilization), valueColor: accent)
                    StatCard(title: "Renderer", value: Formatters.formatPercentage(gpu.rendererUtilization), valueColor: accent)
                    StatCard(title: "Tiler", value: Formatters.formatPercentage(gpu.tilerUtilization), valueColor: accent)
                    StatCard(title: "Allocated", value: Formatters.formatBytes(gpu.allocatedMemory))
                    StatCard(title: "In Use", value: Formatters.formatBytes(gpu.inUseMemory))
                    StatCard(title: "GPU", value: appState.systemInfo.gpuName)
                }
            }
            .padding(32)
        }
    }
}
