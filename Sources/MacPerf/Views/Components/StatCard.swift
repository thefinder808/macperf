import SwiftUI

struct StatCard: View {
    let title: String
    let value: String
    var subtitle: String? = nil
    var valueColor: Color? = nil
    var progress: Double? = nil

    @EnvironmentObject var themeManager: ThemeManager
    @State private var isHovered = false

    var body: some View {
        let theme = themeManager.current
        let accentColor = valueColor ?? theme.primaryText

        VStack(alignment: .leading, spacing: 4) {
            Text(title.uppercased())
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(theme.secondaryText)
                .tracking(0.5)

            Text(value)
                .font(.system(size: 20, weight: .bold).monospacedDigit())
                .foregroundStyle(accentColor)
                .contentTransition(.numericText())
                .animation(.easeInOut(duration: 0.3), value: value)

            if let subtitle {
                Text(subtitle)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.tertiaryText)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isHovered ? accentColor.opacity(0.4) : theme.border, lineWidth: 1)
        )
        .overlay(alignment: .bottom) {
            if let progress {
                GeometryReader { geo in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(accentColor)
                        .frame(width: geo.size.width * min(max(progress / 100, 0), 1), height: 2)
                        .animation(.spring(response: 0.6), value: progress)
                }
                .frame(height: 2)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
