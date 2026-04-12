import SwiftUI

struct MiniGraphCard: View {
    let category: MetricCategory
    let valueText: String
    @ObservedObject var series: TimeSeries

    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovered = false
    @State private var isPressed = false

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: category)

        Button {
            appState.selectedCategory = category
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: category.systemImage)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(category.rawValue)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    Text(valueText)
                        .font(.system(size: 17, weight: .bold, design: .rounded).monospacedDigit())
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: valueText)
                }

                NeonChartView(
                    series: series,
                    color: accent,
                    maxValue: 100,
                    timeRange: .oneMinute,
                    category: category,
                    sizeVariant: .compact
                )
                .frame(height: 64)
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(theme.cardBackground)
                    .shadow(color: theme.cardShadow ? .black.opacity(0.06) : .clear, radius: 3, y: 1)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(isHovered ? accent.opacity(0.4) : (theme.cardShadow ? .clear : theme.border), lineWidth: 1)
            )
            .shadow(color: isHovered && theme.cardShadow ? .black.opacity(0.08) : .clear, radius: 8, y: 4)
            .animation(.spring(response: 0.2), value: isPressed)
            .animation(.easeOut(duration: 0.2), value: isHovered)
        }
        .buttonStyle(.plain)
        .onHover { hovering in
            isHovered = hovering
        }
        .simultaneousGesture(
            DragGesture(minimumDistance: 0)
                .onChanged { _ in isPressed = true }
                .onEnded { _ in isPressed = false }
        )
    }
}
