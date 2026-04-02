import SwiftUI

struct TimeRangePicker: View {
    @Binding var selection: TimeRange
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.current

        HStack(spacing: 0) {
            ForEach(TimeRange.allCases) { range in
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        selection = range
                    }
                } label: {
                    Text(range.label)
                        .font(.system(size: 11, weight: .semibold).monospacedDigit())
                        .foregroundStyle(selection == range ? theme.primaryText : theme.tertiaryText)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(
                            RoundedRectangle(cornerRadius: 5)
                                .fill(selection == range ? theme.sidebarActive : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(3)
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .strokeBorder(theme.border, lineWidth: 1)
        )
    }
}
