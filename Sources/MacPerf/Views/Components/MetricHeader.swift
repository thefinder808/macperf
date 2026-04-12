import SwiftUI

struct MetricHeader: View {
    let category: MetricCategory
    let value: String
    @Binding var timeRange: TimeRange

    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var settingsManager: SettingsManager

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: category)
        let chartType = settingsManager.chartType(for: category)

        HStack(alignment: .center, spacing: 16) {
            Image(systemName: category.systemImage)
                .font(.system(size: 24, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 40, height: 40)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(theme.accent(for: category).opacity(0.15))
                )

            Text(category.rawValue)
                .font(.system(size: 17, weight: .bold))
                .foregroundStyle(theme.primaryText)

            Spacer()

            // Chart type picker
            chartTypePicker(accent: accent, theme: theme, chartType: chartType)

            TimeRangePicker(selection: $timeRange)

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(accent)
                .shadow(color: theme.glowEnabled ? accent.opacity(0.6) : .clear, radius: 12)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: value)
        }
    }

    @ViewBuilder
    private func chartTypePicker(accent: Color, theme: any AppTheme, chartType: ChartType) -> some View {
        HStack(spacing: 2) {
            ForEach(ChartType.allCases) { type in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        settingsManager.chartTypes[category] = type
                    }
                } label: {
                    Image(systemName: type.systemImage)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundStyle(chartType == type ? accent : theme.tertiaryText)
                        .frame(width: 28, height: 24)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(chartType == type ? accent.opacity(0.15) : .clear)
                        )
                }
                .buttonStyle(.plain)
                .help(type.label)
            }
        }
        .padding(2)
        .background(
            RoundedRectangle(cornerRadius: 7)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .strokeBorder(theme.border, lineWidth: 1)
        )
    }
}
