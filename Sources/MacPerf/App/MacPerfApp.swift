import SwiftUI

@main
struct MacPerfApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var themeManager = ThemeManager()
    @StateObject private var settingsManager = SettingsManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
                .background(themeManager.current.windowBackground)
                .preferredColorScheme(colorScheme)
                .sheet(isPresented: $appState.showExport) {
                    ExportSheet()
                        .environmentObject(appState)
                        .environmentObject(themeManager)
                        .environmentObject(settingsManager)
                }
        }
        .defaultSize(width: 1100, height: 700)
        .windowResizability(.contentMinSize)
        .commands {
            // Navigation menu
            CommandMenu("Navigate") {
                Button("Overview") { appState.selectedCategory = .overview }
                    .keyboardShortcut("0", modifiers: .command)
                Button("CPU") { appState.selectedCategory = .cpu }
                    .keyboardShortcut("1", modifiers: .command)
                Button("Memory") { appState.selectedCategory = .memory }
                    .keyboardShortcut("2", modifiers: .command)
                Button("Disk") { appState.selectedCategory = .disk }
                    .keyboardShortcut("3", modifiers: .command)
                Button("Network") { appState.selectedCategory = .network }
                    .keyboardShortcut("4", modifiers: .command)
                Button("GPU") { appState.selectedCategory = .gpu }
                    .keyboardShortcut("5", modifiers: .command)
                Button("Thermal") { appState.selectedCategory = .thermal }
                    .keyboardShortcut("6", modifiers: .command)
                Button("Processes") { appState.selectedCategory = .processes }
                    .keyboardShortcut("7", modifiers: .command)
                Button("Storage") { appState.selectedCategory = .storage }
                    .keyboardShortcut("8", modifiers: .command)

                Divider()

                Button("Command Palette") { appState.showCommandPalette = true }
                    .keyboardShortcut("k", modifiers: .command)
                Button("Search Processes") {
                    appState.selectedCategory = .processes
                    appState.focusProcessSearch = true
                }
                .keyboardShortcut("f", modifiers: .command)
            }

            // Theme menu
            CommandMenu("Theme") {
                ForEach(ThemeOption.allCases) { option in
                    Button(option.rawValue) {
                        themeManager.selectedOption = option
                    }
                }

                Divider()

                Button("Cycle Theme") {
                    themeManager.cycleTheme()
                }
                .keyboardShortcut("t", modifiers: .command)
            }

            // Export
            CommandMenu("Export") {
                Button("Export Current View...") {
                    appState.showExport = true
                }
                .keyboardShortcut("e", modifiers: .command)
            }
        }

        // Menu bar extra
        MenuBarExtra {
            MenuBarView()
                .environmentObject(appState)
                .environmentObject(themeManager)
                .environmentObject(settingsManager)
        } label: {
            HStack(spacing: 4) {
                Image(systemName: "cpu")
                Text(menuBarLabel)
                    .monospacedDigit()
            }
        }
        .menuBarExtraStyle(.window)

        Settings {
            SettingsView()
                .environmentObject(settingsManager)
                .environmentObject(appState)
                .environmentObject(themeManager)
        }
    }

    private var menuBarLabel: String {
        settingsManager.menuBarLabel(from: appState)
    }

    private var colorScheme: ColorScheme? {
        switch themeManager.selectedOption {
        case .dark, .neon: return .dark
        case .light: return .light
        case .system: return nil
        }
    }
}

// MARK: - Export Sheet

struct ExportSheet: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var selectedFormat: ExportFormat = .csv
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 20) {
            Text("Export Data")
                .font(.title2.bold())

            Text("Export all metric history as a file.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Picker("Format", selection: $selectedFormat) {
                ForEach(ExportFormat.allCases) { format in
                    Text(format.rawValue).tag(format)
                }
            }
            .pickerStyle(.segmented)
            .frame(width: 200)

            VStack(alignment: .leading, spacing: 6) {
                formatDescription
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
            .background(RoundedRectangle(cornerRadius: 8).fill(.quaternary))

            HStack {
                Button("Cancel") { dismiss() }
                    .keyboardShortcut(.cancelAction)

                Spacer()

                Button("Export...") {
                    ExportService.export(appState: appState, format: selectedFormat)
                    dismiss()
                }
                .keyboardShortcut(.defaultAction)
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(24)
        .frame(width: 400)
    }

    @ViewBuilder
    private var formatDescription: some View {
        switch selectedFormat {
        case .csv:
            Text("CSV includes timestamped rows for CPU, memory, disk, network, GPU, and temperature over the session.")
                .font(.caption)
                .foregroundStyle(.secondary)
        case .json:
            Text("JSON includes a snapshot of current metrics, system info, and top 10 processes by CPU usage.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
