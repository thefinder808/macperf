import SwiftUI

struct CommandPalette: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var query: String = ""
    @State private var selectedIndex: Int = 0
    @FocusState private var isFocused: Bool

    var body: some View {
        let theme = themeManager.current
        let results = filteredResults

        VStack(spacing: 0) {
            // Search field
            HStack(spacing: 10) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(theme.tertiaryText)
                TextField("Search views, processes, actions...", text: $query)
                    .textFieldStyle(.plain)
                    .font(.system(size: 16))
                    .focused($isFocused)
                    .onSubmit {
                        executeResult(results)
                    }

                if !query.isEmpty {
                    Button {
                        query = ""
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(16)

            Divider().foregroundStyle(theme.border)

            // Results
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        resultRow(result: result, isSelected: index == selectedIndex, theme: theme)
                            .onTapGesture {
                                executeAction(result)
                            }
                    }
                }
            }
            .frame(maxHeight: 350)
        }
        .background(theme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(theme.border, lineWidth: 1))
        .shadow(color: .black.opacity(0.3), radius: 20, y: 10)
        .frame(width: 500)
        .onAppear {
            query = ""
            selectedIndex = 0
            isFocused = true
        }
        .onKeyPress(.upArrow) {
            selectedIndex = max(0, selectedIndex - 1)
            return .handled
        }
        .onKeyPress(.downArrow) {
            selectedIndex = min(results.count - 1, selectedIndex + 1)
            return .handled
        }
        .onKeyPress(.escape) {
            appState.showCommandPalette = false
            return .handled
        }
        .onKeyPress(.return) {
            executeResult(results)
            return .handled
        }
        .onChange(of: query) { _, _ in
            selectedIndex = 0
        }
    }

    @ViewBuilder
    private func resultRow(result: PaletteResult, isSelected: Bool, theme: any AppTheme) -> some View {
        HStack(spacing: 10) {
            Image(systemName: result.icon)
                .font(.system(size: 14))
                .foregroundStyle(result.color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(theme.primaryText)
                if let subtitle = result.subtitle {
                    Text(subtitle)
                        .font(.system(size: 11))
                        .foregroundStyle(theme.tertiaryText)
                }
            }

            Spacer()

            if let shortcut = result.shortcut {
                Text(shortcut)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(theme.tertiaryText)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(RoundedRectangle(cornerRadius: 4).fill(theme.trackBackground))
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .background(isSelected ? theme.sidebarActive : Color.clear)
        .contentShape(Rectangle())
    }

    private func executeResult(_ results: [PaletteResult]) {
        guard selectedIndex < results.count else { return }
        executeAction(results[selectedIndex])
    }

    private func executeAction(_ result: PaletteResult) {
        result.action()
        appState.showCommandPalette = false
    }

    private var filteredResults: [PaletteResult] {
        let q = query.lowercased()
        var results: [PaletteResult] = []

        // Navigation results
        let navResults: [PaletteResult] = MetricCategory.allCases.enumerated().map { index, category in
            let shortcutKey = index <= 8 ? "Cmd+\(index)" : nil
            return PaletteResult(
                id: "nav-\(category.rawValue)",
                title: "Go to \(category.rawValue)",
                subtitle: nil,
                icon: category.systemImage,
                color: themeManager.current.accent(for: category),
                shortcut: shortcutKey,
                action: { [weak appState] in appState?.selectedCategory = category }
            )
        }
        results.append(contentsOf: navResults)

        // Theme results
        for option in ThemeOption.allCases {
            results.append(PaletteResult(
                id: "theme-\(option.rawValue)",
                title: "Theme: \(option.rawValue)",
                subtitle: nil,
                icon: "paintbrush",
                color: themeManager.current.secondaryText,
                shortcut: nil,
                action: { [weak themeManager] in themeManager?.selectedOption = option }
            ))
        }

        // Time range results
        for range in TimeRange.allCases {
            results.append(PaletteResult(
                id: "range-\(range.rawValue)",
                title: "Time Range: \(range.label)",
                subtitle: nil,
                icon: "clock",
                color: themeManager.current.secondaryText,
                shortcut: nil,
                action: { [weak appState] in appState?.selectedTimeRange = range }
            ))
        }

        // Process search results
        if !q.isEmpty {
            let matchingProcesses = appState.processVM.processes
                .filter { $0.name.lowercased().contains(q) }
                .prefix(5)

            for proc in matchingProcesses {
                results.append(PaletteResult(
                    id: "proc-\(proc.pid)",
                    title: proc.name,
                    subtitle: "PID \(proc.pid) — \(Formatters.formatPercentage(proc.cpuUsage)) CPU",
                    icon: "gearshape",
                    color: themeManager.current.accent(for: .processes),
                    shortcut: nil,
                    action: { [weak appState] in
                        appState?.selectedCategory = .processes
                        appState?.processVM.selectedPid = proc.pid
                    }
                ))
            }
        }

        if q.isEmpty { return results }
        return results.filter { $0.title.lowercased().contains(q) }
    }
}

struct PaletteResult {
    let id: String
    let title: String
    let subtitle: String?
    let icon: String
    let color: Color
    let shortcut: String?
    let action: () -> Void
}
