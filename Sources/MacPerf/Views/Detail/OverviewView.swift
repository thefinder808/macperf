import SwiftUI

struct OverviewView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @Environment(\.controlActiveState) private var controlActiveState
    @State private var cardsAppeared = false
    @State private var pulsing = false

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16),
    ]

    private var cardData: [(category: MetricCategory, valueText: String, series: TimeSeries)] {
        var cards: [(MetricCategory, String, TimeSeries)] = [
            (.cpu, Formatters.formatPercentage(appState.cpuUsage, decimals: 0), appState.cpuSeries),
            (.memory, Formatters.formatPercentage(appState.memoryUsage, decimals: 0), appState.memorySeries),
            (.gpu, Formatters.formatPercentage(appState.gpuUsage, decimals: 0), appState.gpuSeries),
            (.disk, Formatters.formatBytesPerSec(appState.diskReadRate), appState.diskReadSeries),
            (.network, Formatters.formatBytesPerSec(appState.networkDownRate), appState.networkDownSeries),
            (.thermal, Formatters.formatTemperature(appState.thermalTemp), appState.thermalSeries),
        ]
        if appState.hasBattery {
            cards.append((.battery, "\(Int(appState.batteryLevel))%", appState.batterySeries))
        }
        return cards
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "square.grid.2x2")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(themeManager.current.accent(for: .overview))
                    Text("Overview")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(themeManager.current.primaryText)

                    // Live pulse dot — only animates while the app is focused, so it
                    // doesn't drive continuous redraws when you're working elsewhere.
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                        .scaleEffect(pulsing ? 1.3 : 1.0)
                        .opacity(pulsing ? 0.7 : 1.0)

                    Spacer()
                    Text(appState.systemInfo.cpuModel)
                        .font(.system(size: 12))
                        .foregroundStyle(themeManager.current.secondaryText)
                }
                .padding(.bottom, 4)

                // Mini graph cards grid with staggered entrance
                LazyVGrid(columns: columns, spacing: 16) {
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
            .padding(32)
        }
        .onAppear {
            cardsAppeared = false
            withAnimation {
                cardsAppeared = true
            }
            syncPulse()
        }
        .onChange(of: controlActiveState) { _, _ in syncPulse() }
    }

    /// Runs the "live" pulse only while the app is active; stops it when the app
    /// loses focus to avoid continuous off-focus redraws.
    private func syncPulse() {
        let active = controlActiveState != .inactive
        if active && !pulsing {
            withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                pulsing = true
            }
        } else if !active && pulsing {
            withAnimation(.easeInOut(duration: 0.3)) { pulsing = false }
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
