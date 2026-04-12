import SwiftUI

struct SidebarMetricRow: View {
    let category: MetricCategory
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Label {
            HStack(spacing: 6) {
                VStack(alignment: .leading, spacing: 1) {
                    Text(category.rawValue)
                        .font(.system(size: 13, weight: .semibold))

                    if !currentValueText.isEmpty {
                        Text(currentValueText)
                            .font(.system(size: 14, weight: .bold).monospacedDigit())
                            .foregroundStyle(themeManager.current.accent(for: category))
                            .contentTransition(.numericText())
                            .animation(.easeInOut(duration: 0.3), value: currentValueText)
                    }
                }

                Spacer(minLength: 4)

                if category.isHardwareMonitor {
                    NeonChartView(
                        series: seriesForCategory,
                        color: themeManager.current.accent(for: category),
                        maxValue: 0,
                        timeRange: .oneMinute,
                        category: category,
                        sizeVariant: .compact
                    )
                    .frame(width: 72, height: 28)
                }
            }
        } icon: {
            Image(systemName: category.systemImage)
                .foregroundStyle(themeManager.current.accent(for: category))
        }
        .padding(.vertical, 2)
    }

    private var currentValueText: String {
        switch category {
        case .overview:
            return ""
        case .cpu:
            return Formatters.formatPercentage(appState.cpuUsage, decimals: 0)
        case .memory:
            return Formatters.formatPercentage(appState.memoryUsage, decimals: 0)
        case .disk:
            return Formatters.formatBytesPerSec(appState.diskReadRate)
        case .network:
            return Formatters.formatBytesPerSec(appState.networkDownRate)
        case .gpu:
            return Formatters.formatPercentage(appState.gpuUsage, decimals: 0)
        case .thermal:
            return Formatters.formatTemperature(appState.thermalTemp)
        case .battery:
            return "\(Int(appState.batteryLevel))%"
        case .processes:
            return "—"
        case .storage:
            return "—"
        }
    }

    private var seriesForCategory: TimeSeries {
        switch category {
        case .cpu: return appState.cpuSeries
        case .memory: return appState.memorySeries
        case .disk: return appState.diskReadSeries
        case .network: return appState.networkDownSeries
        case .gpu: return appState.gpuSeries
        case .thermal: return appState.thermalSeries
        case .battery: return appState.batterySeries
        default: return TimeSeries()
        }
    }
}
