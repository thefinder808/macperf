import SwiftUI

struct DiskDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    private let statsColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: .disk)
        let disk = appState.diskVM

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                MetricHeader(
                    category: .disk,
                    value: Formatters.formatBytesPerSec(disk.readBytesPerSec),
                    timeRange: $appState.selectedTimeRange
                )

                // Legend
                HStack(spacing: 20) {
                    legendItem(color: accent, label: "Read")
                    legendItem(color: accent.opacity(0.5), label: "Write")
                }

                // Dual-line graph
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

                LazyVGrid(columns: statsColumns, spacing: 12) {
                    StatCard(title: "Read Speed", value: Formatters.formatBytesPerSec(disk.readBytesPerSec), valueColor: accent)
                    StatCard(title: "Write Speed", value: Formatters.formatBytesPerSec(disk.writeBytesPerSec), valueColor: accent)
                    StatCard(title: "Read Ops/s", value: Formatters.formatCount(Int(disk.readOpsPerSec)))
                    StatCard(title: "Write Ops/s", value: Formatters.formatCount(Int(disk.writeOpsPerSec)))
                    StatCard(title: "Total Read", value: Formatters.formatBytes(disk.totalBytesRead))
                    StatCard(title: "Total Written", value: Formatters.formatBytes(disk.totalBytesWritten))
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
