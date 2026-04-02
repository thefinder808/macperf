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
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(accent)
                    Text(category.rawValue)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                    Spacer()
                    Text(valueText)
                        .font(.system(size: 18, weight: .bold).monospacedDigit())
                        .foregroundStyle(accent)
                        .contentTransition(.numericText())
                        .animation(.easeInOut(duration: 0.3), value: valueText)
                }

                MiniSparkline(series: series, color: accent, pointCount: 60)
                    .frame(height: 50)
            }
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(theme.cardBackground)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .strokeBorder(isHovered ? accent.opacity(0.4) : theme.border, lineWidth: 1)
            )
            .scaleEffect(isPressed ? 0.97 : 1.0)
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
