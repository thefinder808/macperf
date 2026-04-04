import SwiftUI

struct MetricHeader: View {
    let category: MetricCategory
    let value: String
    @Binding var timeRange: TimeRange

    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: category)

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

            TimeRangePicker(selection: $timeRange)

            Text(value)
                .font(.system(size: 32, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(accent)
                .shadow(color: theme.glowEnabled ? accent.opacity(0.6) : .clear, radius: 12)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: value)
        }
    }
}
