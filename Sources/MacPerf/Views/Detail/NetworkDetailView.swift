import SwiftUI

struct NetworkDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    private let statsColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: .network)
        let net = appState.networkVM

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MetricHeader(
                    category: .network,
                    value: Formatters.formatBytesPerSec(net.downloadBytesPerSec),
                    timeRange: $appState.selectedTimeRange
                )

                // Legend
                HStack(spacing: 20) {
                    legendItem(color: accent, label: "Download")
                    legendItem(color: accent.opacity(0.5), label: "Upload")
                }

                // Dual-line graph
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

                LazyVGrid(columns: statsColumns, spacing: 12) {
                    StatCard(title: "Download", value: Formatters.formatBytesPerSec(net.downloadBytesPerSec), valueColor: accent)
                    StatCard(title: "Upload", value: Formatters.formatBytesPerSec(net.uploadBytesPerSec), valueColor: accent)
                    StatCard(title: "Total Downloaded", value: Formatters.formatBytes(net.totalDownloaded))
                    StatCard(title: "Total Uploaded", value: Formatters.formatBytes(net.totalUploaded))
                    StatCard(title: "Interface", value: net.activeInterface)
                }
            }
            .padding(32)
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 16, height: 3)
            Text(label)
                .font(.system(size: 12))
                .foregroundStyle(themeManager.current.secondaryText)
        }
    }
}
