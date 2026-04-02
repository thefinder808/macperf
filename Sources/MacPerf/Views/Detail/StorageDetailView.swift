import SwiftUI

struct StorageDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: .storage)
        let storage = appState.storageVM

        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Header
                HStack(spacing: 14) {
                    Image(systemName: "externaldrive")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 40, height: 40)
                        .background(
                            RoundedRectangle(cornerRadius: 10)
                                .fill(accent.opacity(0.15))
                        )

                    Text("Storage")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme.primaryText)

                    Spacer()

                    Text("\(storage.volumes.count) volume\(storage.volumes.count == 1 ? "" : "s")")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.secondaryText)
                }

                // Volume cards
                ForEach(storage.volumes) { volume in
                    volumeCard(theme: theme, accent: accent, volume: volume)
                }

                if storage.volumes.isEmpty {
                    Text("No volumes detected")
                        .font(.system(size: 14))
                        .foregroundStyle(theme.tertiaryText)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 40)
                }
            }
            .padding(28)
        }
    }

    @ViewBuilder
    private func volumeCard(theme: any AppTheme, accent: Color, volume: StorageMonitor.VolumeInfo) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            // Volume name + mount point
            HStack {
                Image(systemName: volume.isRemovable ? "externaldrive" : "internaldrive.fill")
                    .foregroundStyle(accent)
                VStack(alignment: .leading, spacing: 2) {
                    Text(volume.name)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(theme.primaryText)
                    Text(volume.mountPoint)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.tertiaryText)
                }
                Spacer()
                Text(volume.fileSystem)
                    .font(.system(size: 11))
                    .foregroundStyle(theme.tertiaryText)
            }

            // Usage bar
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(theme.trackBackground)

                    RoundedRectangle(cornerRadius: 6)
                        .fill(barColor(percent: volume.usedPercent, accent: accent))
                        .frame(width: max(4, geo.size.width * volume.usedPercent / 100))
                        .shadow(
                            color: theme.glowEnabled ? barColor(percent: volume.usedPercent, accent: accent).opacity(0.4) : .clear,
                            radius: 4
                        )
                }
            }
            .frame(height: 20)

            // Stats row
            HStack(spacing: 24) {
                volumeStat(theme: theme, label: "Used", value: Formatters.formatBytes(volume.usedBytes))
                volumeStat(theme: theme, label: "Free", value: Formatters.formatBytes(volume.freeBytes))
                volumeStat(theme: theme, label: "Total", value: Formatters.formatBytes(volume.totalBytes))
                Spacer()
                Text(Formatters.formatPercentage(volume.usedPercent, decimals: 1) + " used")
                    .font(.system(size: 13, weight: .semibold).monospacedDigit())
                    .foregroundStyle(barColor(percent: volume.usedPercent, accent: accent))
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(theme.cardBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(theme.border, lineWidth: 1)
        )
    }

    private func volumeStat(theme: any AppTheme, label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label.uppercased())
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.tertiaryText)
                .tracking(0.5)
            Text(value)
                .font(.system(size: 13, weight: .medium).monospacedDigit())
                .foregroundStyle(theme.primaryText)
        }
    }

    private func barColor(percent: Double, accent: Color) -> Color {
        if percent > 90 { return .red }
        if percent > 75 { return .orange }
        return accent
    }
}
