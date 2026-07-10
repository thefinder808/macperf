import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var settingsManager: SettingsManager
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @EnvironmentObject var updater: UpdaterService

    var body: some View {
        let theme = themeManager.current

        ScrollView {
            VStack(alignment: .leading, spacing: 24) {
                // Header
                HStack(spacing: 12) {
                    Image(systemName: "gearshape")
                        .font(.system(size: 20, weight: .semibold))
                        .foregroundStyle(theme.secondaryText)
                    Text("Settings")
                        .font(.system(size: 17, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                }

                // Appearance section
                settingsSection(title: "Appearance", icon: "paintbrush") {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Theme")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(theme.secondaryText)
                            .tracking(0.5)
                            .textCase(.uppercase)

                        HStack(spacing: 12) {
                            ForEach(ThemeOption.allCases) { option in
                                themeButton(option: option, theme: theme)
                            }
                        }
                    }
                }

                // Menu Bar section
                settingsSection(title: "Menu Bar", icon: "menubar.rectangle") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 0) {
                            Image(systemName: "textformat.size")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.secondaryText)
                                .frame(width: 28, alignment: .center)

                            Text("Label metrics")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.primaryText)

                            Spacer()

                            Toggle("", isOn: $settingsManager.useTextLabels)
                                .toggleStyle(.switch)
                                .tint(theme.accent(for: .overview))
                                .labelsHidden()
                        }
                        .padding(.vertical, 4)

                        Divider()

                        VStack(spacing: 0) {
                            ForEach(MenuBarMetric.allCases) { metric in
                                metricToggleRow(metric: metric, theme: theme)
                                if metric != MenuBarMetric.allCases.last {
                                    Divider()
                                        .padding(.leading, 38)
                                }
                            }
                        }
                    }
                }

                // Sampling section
                settingsSection(title: "Sampling", icon: "timer") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 0) {
                            Image(systemName: "speedometer")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.secondaryText)
                                .frame(width: 28, alignment: .center)

                            Text("Update interval")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.primaryText)

                            Spacer()

                            Picker("", selection: $appState.samplingInterval) {
                                Text("1s").tag(1.0)
                                Text("2s").tag(2.0)
                                Text("5s").tag(5.0)
                            }
                            .pickerStyle(.segmented)
                            .labelsHidden()
                            .frame(width: 150)
                        }
                        .padding(.vertical, 4)

                        Text("Lower frequency uses less battery. Charts and the menu bar refresh at this rate.")
                            .font(.system(size: 11))
                            .foregroundStyle(theme.secondaryText)
                            .padding(.leading, 28)
                    }
                }

                // Software updates section
                settingsSection(title: "Software Updates", icon: "arrow.triangle.2.circlepath") {
                    // Sparkle's automaticallyChecksForUpdates is a plain get/set
                    // on the updater controller (not @Published), so wrap it in
                    // a manual Binding.
                    let autoCheck = Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: { updater.automaticallyChecksForUpdates = $0 }
                    )
                    let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"

                    VStack(alignment: .leading, spacing: 12) {
                        HStack(spacing: 0) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.secondaryText)
                                .frame(width: 28, alignment: .center)

                            Text("Automatically check for updates")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.primaryText)

                            Spacer()

                            Toggle("", isOn: autoCheck)
                                .toggleStyle(.switch)
                                .tint(theme.accent(for: .overview))
                                .labelsHidden()
                        }
                        .padding(.vertical, 4)

                        Divider()

                        HStack(spacing: 0) {
                            Image(systemName: "sparkles")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.secondaryText)
                                .frame(width: 28, alignment: .center)

                            Text("Current version: \(version)")
                                .font(.system(size: 13))
                                .foregroundStyle(theme.primaryText)

                            Spacer()

                            Button("Check Now") { updater.checkForUpdates() }
                                .disabled(!updater.canCheckForUpdates)
                        }
                        .padding(.vertical, 4)
                    }
                }

            }
            .padding(32)
        }
    }

    // MARK: - Components

    @ViewBuilder
    private func settingsSection<Content: View>(title: String, icon: String, @ViewBuilder content: () -> Content) -> some View {
        let theme = themeManager.current

        VStack(alignment: .leading, spacing: 16) {
            Label {
                Text(title)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(theme.primaryText)
            } icon: {
                Image(systemName: icon)
                    .font(.system(size: 13))
                    .foregroundStyle(theme.secondaryText)
            }

            content()
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
                .strokeBorder(theme.cardShadow ? .clear : theme.border, lineWidth: 1)
        )
    }

    @ViewBuilder
    private func themeButton(option: ThemeOption, theme: any AppTheme) -> some View {
        let isSelected = themeManager.selectedOption == option

        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                themeManager.selectedOption = option
            }
        } label: {
            VStack(spacing: 8) {
                RoundedRectangle(cornerRadius: 8)
                    .fill(previewColor(for: option))
                    .frame(width: 48, height: 32)
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(isSelected ? theme.accent(for: .overview) : theme.border, lineWidth: isSelected ? 2 : 1)
                    )

                Text(option.rawValue)
                    .font(.system(size: 11, weight: isSelected ? .semibold : .regular))
                    .foregroundStyle(isSelected ? theme.primaryText : theme.secondaryText)
            }
        }
        .buttonStyle(.plain)
    }

    private func previewColor(for option: ThemeOption) -> Color {
        switch option {
        case .system: return Color(hex: 0x808080)
        case .dark: return Color(hex: 0x1C1C20)
        case .light: return Color(hex: 0xF8F8FA)
        case .neon: return Color(hex: 0x0A0A0F)
        }
    }

    @ViewBuilder
    private func metricToggleRow(metric: MenuBarMetric, theme: any AppTheme) -> some View {
        HStack(spacing: 0) {
            Image(systemName: metric.systemImage)
                .font(.system(size: 13))
                .foregroundStyle(theme.secondaryText)
                .frame(width: 28, alignment: .center)

            Text(metric.rawValue)
                .font(.system(size: 13))
                .foregroundStyle(theme.primaryText)

            Spacer()

            Toggle("", isOn: binding(for: metric))
                .toggleStyle(.switch)
                .tint(theme.accent(for: .overview))
                .labelsHidden()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
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
