import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var cardsAppeared = false

    private let columns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    private var cardData: [(category: MetricCategory, valueText: String, series: TimeSeries)] {
        [
            (.cpu, Formatters.formatPercentage(appState.cpuUsage, decimals: 0), appState.cpuSeries),
            (.memory, Formatters.formatPercentage(appState.memoryUsage, decimals: 0), appState.memorySeries),
            (.gpu, Formatters.formatPercentage(appState.gpuUsage, decimals: 0), appState.gpuSeries),
            (.disk, Formatters.formatBytesPerSec(appState.diskReadRate), appState.diskReadSeries),
            (.network, Formatters.formatBytesPerSec(appState.networkDownRate), appState.networkDownSeries),
            (.thermal, Formatters.formatTemperature(appState.thermalTemp), appState.thermalSeries),
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themeManager.current.accent(for: .overview))
                    Text("Overview")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(themeManager.current.primaryText)

                    // Live pulse dot
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                        .scaleEffect(cardsAppeared ? 1.3 : 1.0)
                        .opacity(cardsAppeared ? 0.7 : 1.0)
                        .animation(.easeInOut(duration: 2).repeatForever(autoreverses: true), value: cardsAppeared)

                    Spacer()
                    Text(appState.systemInfo.cpuModel)
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.current.secondaryText)
                }
                .padding(.bottom, 4)

                // Mini graph cards grid with staggered entrance
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(Array(cardData.enumerated()), id: \.element.category) { index, data in
                        MiniGraphCard(
                            category: data.category,
                            valueText: data.valueText,
                            series: data.series
                        )
                        .opacity(cardsAppeared ? 1 : 0)
                        .offset(y: cardsAppeared ? 0 : 10)
                        .animation(
                            .spring(response: 0.4, dampingFraction: 0.8)
                            .delay(Double(index) * 0.05),
                            value: cardsAppeared
                        )
                    }
                }

                // System info footer
                HStack(spacing: 24) {
                    infoItem(label: "Cores", value: "\(appState.systemInfo.totalCores)")
                    infoItem(label: "RAM", value: appState.systemInfo.totalRAMFormatted)
                    infoItem(label: "OS", value: appState.systemInfo.osVersion)
                }
                .padding(.top, 8)
            }
            .padding(28)
        }
        .onAppear {
            cardsAppeared = false
            withAnimation {
                cardsAppeared = true
            }
        }
    }

    private func infoItem(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(themeManager.current.tertiaryText)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(themeManager.current.secondaryText)
        }
    }
}
