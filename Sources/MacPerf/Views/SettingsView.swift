import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager

    var body: some View {
        Form {
            Section {
                Text("Choose which metrics appear in the macOS menu bar.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                ForEach(MenuBarMetric.allCases) { metric in
                    Toggle(isOn: binding(for: metric)) {
                        Label(metric.rawValue, systemImage: metric.systemImage)
                    }
                }
            } header: {
                Text("Menu Bar Metrics")
            }

            Section {
                HStack(spacing: 6) {
                    Image(systemName: "cpu")
                        .foregroundStyle(.secondary)
                    Text(settingsManager.menuBarLabel(from: appState))
                        .monospacedDigit()
                        .font(.system(size: 13))
                }
                .padding(.vertical, 4)
            } header: {
                Text("Preview")
            }
        }
        .formStyle(.grouped)
        .frame(width: 360, height: 380)
    }

    private func binding(for metric: MenuBarMetric) -> Binding<Bool> {
        Binding(
            get: { settingsManager.enabledMenuBarMetrics.contains(metric) },
            set: { enabled in
                if enabled {
                    settingsManager.enabledMenuBarMetrics.insert(metric)
                } else {
                    settingsManager.enabledMenuBarMetrics.remove(metric)
                }
            }
        )
    }
}
