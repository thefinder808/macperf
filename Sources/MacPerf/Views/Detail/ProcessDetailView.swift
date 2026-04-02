import SwiftUI

struct ProcessDetailView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var themeManager: ThemeManager
    @State private var searchText: String = ""
    @State private var showTree: Bool = false
    @FocusState private var isSearchFocused: Bool

    private var proc: ProcessViewModel { appState.processVM }

    private let summaryColumns = [
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
        GridItem(.flexible(), spacing: 12),
    ]

    var body: some View {
        let theme = themeManager.current
        let accent = theme.accent(for: .processes)

        VStack(spacing: 0) {
            // Fixed header
            VStack(alignment: .leading, spacing: 16) {
                // Title row
                HStack(spacing: 14) {
                    Image(systemName: "list.bullet.rectangle")
                        .font(.system(size: 24, weight: .semibold))
                        .foregroundStyle(accent)
                        .frame(width: 40, height: 40)
                        .background(RoundedRectangle(cornerRadius: 10).fill(accent.opacity(0.15)))

                    Text("Processes")
                        .font(.system(size: 22, weight: .bold))
                        .foregroundStyle(theme.primaryText)

                    Spacer()

                    // Tree/Flat toggle
                    Picker("View", selection: $showTree) {
                        Text("Flat").tag(false)
                        Text("Tree").tag(true)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 120)
                    .onChange(of: showTree) { _, newValue in
                        proc.showTree = newValue
                    }

                    Text("\(proc.processCount)")
                        .font(.system(size: 36, weight: .bold).monospacedDigit())
                        .foregroundStyle(accent)
                }

                // Summary cards
                LazyVGrid(columns: summaryColumns, spacing: 12) {
                    StatCard(title: "Total CPU", value: Formatters.formatPercentage(proc.totalCPU, decimals: 1), valueColor: theme.accent(for: .cpu))
                    StatCard(title: "Total Memory", value: Formatters.formatBytes(proc.totalMemory), valueColor: theme.accent(for: .memory))
                    StatCard(title: "Threads", value: Formatters.formatCount(proc.totalThreads))
                    StatCard(title: "Processes", value: Formatters.formatCount(proc.processCount))
                }

                // Search bar
                HStack(spacing: 8) {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(theme.tertiaryText)
                    TextField("Search processes...", text: $searchText)
                        .textFieldStyle(.plain)
                        .font(.system(size: 13))
                        .focused($isSearchFocused)
                        .onChange(of: searchText) { _, newValue in
                            proc.searchText = newValue
                        }
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(theme.cardBackground))
                .overlay(RoundedRectangle(cornerRadius: 8).strokeBorder(theme.border, lineWidth: 1))
            }
            .padding(.horizontal, 28)
            .onChange(of: appState.focusProcessSearch) { _, shouldFocus in
                if shouldFocus {
                    isSearchFocused = true
                    appState.focusProcessSearch = false
                }
            }
            .padding(.top, 28)
            .padding(.bottom, 12)

            // Table + optional detail drawer
            HSplitView {
                processTable(theme: theme)

                // Detail drawer when a process is selected
                if let selected = proc.selectedProcess {
                    processDrawer(theme: theme, process: selected)
                        .frame(minWidth: 260, idealWidth: 300, maxWidth: 360)
                }
            }
        }
    }

    // MARK: - Table

    @ViewBuilder
    private func processTable(theme: any AppTheme) -> some View {
        let nodes = proc.treeNodes

        VStack(spacing: 0) {
            // Header row
            HStack(spacing: 0) {
                sortableHeader("Name", column: .name, width: nil, theme: theme)
                sortableHeader("PID", column: .pid, width: 55, theme: theme)
                sortableHeader("CPU %", column: .cpu, width: 80, theme: theme)
                sortableHeader("Memory", column: .memory, width: 80, theme: theme)
                sortableHeader("Energy", column: .energy, width: 75, theme: theme)
                sortableHeader("Threads", column: .threads, width: 65, theme: theme)
                sortableHeader("State", column: .state, width: 75, theme: theme)
            }
            .padding(.horizontal, 28)
            .padding(.vertical, 6)
            .background(theme.cardBackground)
            .overlay(alignment: .bottom) {
                Rectangle().fill(theme.border).frame(height: 1)
            }

            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(nodes) { node in
                        processRow(node: node, theme: theme)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func sortableHeader(_ title: String, column: ProcessSortColumn, width: CGFloat?, theme: any AppTheme) -> some View {
        Button {
            proc.toggleSort(column)
        } label: {
            HStack(spacing: 4) {
                Text(title)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(proc.sortColumn == column ? theme.primaryText : theme.secondaryText)
                    .tracking(0.3)
                if proc.sortColumn == column {
                    Image(systemName: proc.sortAscending ? "chevron.up" : "chevron.down")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(theme.secondaryText)
                }
                if width == nil { Spacer() }
            }
        }
        .buttonStyle(.plain)
        .frame(width: width, alignment: .leading)
    }

    @ViewBuilder
    private func processRow(node: ProcessTreeNode, theme: any AppTheme) -> some View {
        let process = node.process
        let isSelected = proc.selectedPid == process.pid

        HStack(spacing: 0) {
            // Name with tree indentation
            HStack(spacing: 4) {
                if proc.showTree {
                    // Indent
                    ForEach(0..<node.depth, id: \.self) { _ in
                        Color.clear.frame(width: 16)
                    }

                    // Expand/collapse or leaf indicator
                    if node.hasChildren {
                        Button {
                            proc.toggleExpanded(process.pid)
                        } label: {
                            Image(systemName: node.isExpanded ? "chevron.down" : "chevron.right")
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(theme.tertiaryText)
                                .frame(width: 16, height: 16)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(width: 16)
                    }
                }

                Text(process.name)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(theme.primaryText)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("\(process.pid)")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(theme.tertiaryText)
                .frame(width: 55, alignment: .leading)

            // CPU %
            HStack(spacing: 4) {
                Text(Formatters.formatPercentage(process.cpuUsage, decimals: 1))
                    .font(.system(size: 12, weight: .medium).monospacedDigit())
                    .foregroundStyle(theme.accent(for: .cpu))
                RoundedRectangle(cornerRadius: 2)
                    .fill(theme.accent(for: .cpu))
                    .frame(width: max(2, min(30, process.cpuUsage * 0.6)), height: 4)
            }
            .frame(width: 80, alignment: .leading)

            Text(Formatters.formatBytes(process.memoryBytes))
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(theme.primaryText)
                .frame(width: 80, alignment: .leading)

            // Energy
            HStack(spacing: 4) {
                Text(process.energyImpact.rawValue)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(energyColor(process.energyImpact, theme: theme))
                RoundedRectangle(cornerRadius: 2)
                    .fill(energyColor(process.energyImpact, theme: theme))
                    .frame(width: energyBarWidth(process.energyImpact), height: 4)
            }
            .frame(width: 75, alignment: .leading)

            Text("\(process.threadCount)")
                .font(.system(size: 12).monospacedDigit())
                .foregroundStyle(theme.primaryText)
                .frame(width: 65, alignment: .leading)

            Text(process.state.rawValue)
                .font(.system(size: 12))
                .foregroundStyle(process.state == .running ? theme.accent(for: .disk) : theme.tertiaryText)
                .frame(width: 75, alignment: .leading)
        }
        .padding(.horizontal, 28)
        .padding(.vertical, 5)
        .background(isSelected ? theme.sidebarActive.opacity(0.5) : Color.clear)
        .contentShape(Rectangle())
        .onTapGesture {
            proc.selectedPid = (proc.selectedPid == process.pid) ? nil : process.pid
        }
        .contextMenu {
            Button("Kill Process (SIGTERM)") {
                proc.killProcess(process.pid)
            }
            Button("Force Kill (SIGKILL)") {
                proc.forceKillProcess(process.pid)
            }
            Divider()
            Button(proc.selectedPid == process.pid ? "Hide Details" : "Show Details") {
                proc.selectedPid = (proc.selectedPid == process.pid) ? nil : process.pid
            }
        }
        .overlay(alignment: .bottom) {
            Rectangle().fill(theme.border.opacity(0.3)).frame(height: 0.5)
        }
    }

    // MARK: - Detail Drawer

    @ViewBuilder
    private func processDrawer(theme: any AppTheme, process: ProcessEntry) -> some View {
        let history = proc.cpuHistory[process.pid] ?? []

        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // Header
                HStack {
                    Text(process.name)
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(theme.primaryText)
                    Spacer()
                    Button {
                        proc.selectedPid = nil
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundStyle(theme.tertiaryText)
                    }
                    .buttonStyle(.plain)
                }

                // CPU sparkline
                if history.count >= 2 {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("CPU HISTORY")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(theme.tertiaryText)
                            .tracking(0.5)

                        Canvas { context, size in
                            drawSparkline(context: context, size: size, points: history, color: theme.accent(for: .cpu))
                        }
                        .frame(height: 40)
                        .background(RoundedRectangle(cornerRadius: 6).fill(theme.graphBackground))
                    }
                }

                // Info rows
                Divider().foregroundStyle(theme.border)

                infoRow(theme: theme, label: "PID", value: "\(process.pid)")
                infoRow(theme: theme, label: "Parent PID", value: "\(process.parentPid)")
                infoRow(theme: theme, label: "CPU", value: Formatters.formatPercentage(process.cpuUsage))
                infoRow(theme: theme, label: "Memory", value: Formatters.formatBytes(process.memoryBytes))
                infoRow(theme: theme, label: "Threads", value: "\(process.threadCount)")
                infoRow(theme: theme, label: "State", value: process.state.rawValue)
                infoRow(theme: theme, label: "Energy", value: process.energyImpact.rawValue)

                Divider().foregroundStyle(theme.border)

                // Launch path
                launchPathSection(theme: theme, pid: process.pid)

                Divider().foregroundStyle(theme.border)

                // Actions
                VStack(spacing: 8) {
                    Button {
                        proc.killProcess(process.pid)
                    } label: {
                        Label("Kill Process", systemImage: "xmark.octagon")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)

                    Button {
                        proc.forceKillProcess(process.pid)
                    } label: {
                        Label("Force Kill", systemImage: "xmark.octagon.fill")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.bordered)
                    .tint(.red)
                }
            }
            .padding(16)
        }
        .background(theme.sidebarBackground)
        .overlay(alignment: .leading) {
            Rectangle().fill(theme.border).frame(width: 1)
        }
    }

    @ViewBuilder
    private func infoRow(theme: any AppTheme, label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(theme.secondaryText)
            Spacer()
            Text(value)
                .font(.system(size: 12, weight: .medium).monospacedDigit())
                .foregroundStyle(theme.primaryText)
        }
    }

    @ViewBuilder
    private func launchPathSection(theme: any AppTheme, pid: Int32) -> some View {
        let path = getProcessPath(pid: pid)

        VStack(alignment: .leading, spacing: 4) {
            Text("PATH")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(theme.tertiaryText)
                .tracking(0.5)

            Text(path)
                .font(.system(size: 11, design: .monospaced))
                .foregroundStyle(theme.secondaryText)
                .lineLimit(3)
                .textSelection(.enabled)
        }
    }

    // MARK: - Helpers

    private func getProcessPath(pid: Int32) -> String {
        var pathBuffer = [CChar](repeating: 0, count: Int(MAXPATHLEN))
        proc_pidpath(pid, &pathBuffer, UInt32(MAXPATHLEN))
        let path = String(cString: pathBuffer)
        return path.isEmpty ? "Unknown" : path
    }

    private func drawSparkline(context: GraphicsContext, size: CGSize, points: [Double], color: Color) {
        guard points.count >= 2 else { return }
        let maxVal = max(points.max() ?? 1, 1)
        let step = size.width / CGFloat(points.count - 1)

        var path = Path()
        for (i, value) in points.enumerated() {
            let x = CGFloat(i) * step
            let y = size.height - (value / maxVal) * size.height
            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
            else { path.addLine(to: CGPoint(x: x, y: y)) }
        }
        context.stroke(path, with: .color(color), lineWidth: 1.5)

        // Fill
        var fillPath = path
        fillPath.addLine(to: CGPoint(x: size.width, y: size.height))
        fillPath.addLine(to: CGPoint(x: 0, y: size.height))
        fillPath.closeSubpath()
        context.fill(fillPath, with: .linearGradient(
            Gradient(colors: [color.opacity(0.3), color.opacity(0.05)]),
            startPoint: .zero, endPoint: CGPoint(x: 0, y: size.height)
        ))
    }

    private func energyColor(_ level: ProcessEntry.EnergyLevel, theme: any AppTheme) -> Color {
        switch level {
        case .low: return theme.accent(for: .disk)
        case .medium: return .yellow
        case .high: return .red
        }
    }

    private func energyBarWidth(_ level: ProcessEntry.EnergyLevel) -> CGFloat {
        switch level {
        case .low: return 8
        case .medium: return 16
        case .high: return 24
        }
    }
}
