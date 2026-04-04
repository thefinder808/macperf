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

        HStack(spacing: 0) {
            // Left-edge color strip
            RoundedRectangle(cornerRadius: 2)
                .fill(accentColor)
                .frame(width: 3)
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 4) {
                Text(title.uppercased())
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(theme.secondaryText)
                    .tracking(0.5)

                Text(value)
                    .font(.system(size: 17, weight: .bold).monospacedDigit())
                    .foregroundStyle(accentColor)
                    .contentTransition(.numericText())
                    .animation(.easeInOut(duration: 0.3), value: value)

                if let subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.tertiaryText)
                }
            }
            .padding(.leading, 12)
            .padding(.vertical, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
                .shadow(color: theme.cardShadow ? .black.opacity(0.06) : .clear, radius: 3, y: 1)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(isHovered ? accentColor.opacity(0.4) : (theme.cardShadow ? .clear : theme.border), lineWidth: 1)
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
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .animation(.easeOut(duration: 0.2), value: isHovered)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}
