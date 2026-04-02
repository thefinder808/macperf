import SwiftUI
import Combine

enum ProcessSortColumn: String, CaseIterable {
    case name = "Name"
    case pid = "PID"
    case cpu = "CPU %"
    case memory = "Memory"
    case energy = "Energy"
    case disk = "Disk I/O"
    case connections = "Conns"
    case threads = "Threads"
    case state = "State"
}

/// A flattened tree node for display
struct ProcessTreeNode: Identifiable {
    let id: Int32
    let process: ProcessEntry
    let depth: Int
    let hasChildren: Bool
    var isExpanded: Bool
}

final class ProcessViewModel: ObservableObject {
    let monitor = ProcessMonitor()

    @Published var processes: [ProcessEntry] = []
    @Published var searchText: String = ""
    @Published var sortColumn: ProcessSortColumn = .cpu
    @Published var sortAscending: Bool = false
    @Published var showTree: Bool = false
    @Published var expandedPids: Set<Int32> = []
    @Published var selectedPid: Int32? = nil

    // Per-process CPU sparkline history (keeps last 60 values)
    var cpuHistory: [Int32: [Double]] = [:]

    // On-demand detail for selected process
    @Published var selectedDetail: (openFiles: Int, connections: Int)? = nil

    // Sample profiling
    @Published var sampleOutput: String? = nil
    @Published var isSampling: Bool = false

    var filteredProcesses: [ProcessEntry] {
        var result = processes
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            result = result.filter { $0.name.lowercased().contains(query) }
        }
        result.sort(by: sortComparator)
        return result
    }

    var treeNodes: [ProcessTreeNode] {
        guard showTree && searchText.isEmpty else {
            return filteredProcesses.map {
                ProcessTreeNode(id: $0.pid, process: $0, depth: 0, hasChildren: false, isExpanded: false)
            }
        }

        let pidSet = Set(processes.map(\.pid))
        var childrenMap: [Int32: [ProcessEntry]] = [:]
        var roots: [ProcessEntry] = []

        for proc in processes {
            if proc.parentPid <= 0 || !pidSet.contains(proc.parentPid) || proc.parentPid == proc.pid {
                roots.append(proc)
            } else {
                childrenMap[proc.parentPid, default: []].append(proc)
            }
        }

        roots.sort(by: sortComparator)
        for key in childrenMap.keys {
            childrenMap[key]?.sort(by: sortComparator)
        }

        var nodes: [ProcessTreeNode] = []
        func flatten(_ entries: [ProcessEntry], depth: Int) {
            for entry in entries {
                let children = childrenMap[entry.pid] ?? []
                let hasChildren = !children.isEmpty
                let isExpanded = expandedPids.contains(entry.pid)
                nodes.append(ProcessTreeNode(
                    id: entry.pid,
                    process: entry,
                    depth: depth,
                    hasChildren: hasChildren,
                    isExpanded: isExpanded
                ))
                if isExpanded && hasChildren {
                    flatten(children, depth: depth + 1)
                }
            }
        }
        flatten(roots, depth: 0)
        return nodes
    }

    var selectedProcess: ProcessEntry? {
        guard let pid = selectedPid else { return nil }
        return processes.first { $0.pid == pid }
    }

    // Summary stats
    var totalCPU: Double { processes.reduce(0) { $0 + $1.cpuUsage } }
    var totalMemory: UInt64 { processes.reduce(0) { $0 + $1.memoryBytes } }
    var totalThreads: Int { processes.reduce(0) { $0 + Int($1.threadCount) } }
    var processCount: Int { processes.count }

    func update() {
        processes = monitor.sample()

        for proc in processes {
            var history = cpuHistory[proc.pid] ?? []
            history.append(proc.cpuUsage)
            if history.count > 60 { history.removeFirst(history.count - 60) }
            cpuHistory[proc.pid] = history
        }

        let activePids = Set(processes.map(\.pid))
        cpuHistory = cpuHistory.filter { activePids.contains($0.key) }

        // Refresh FD detail for selected process
        if let pid = selectedPid {
            let detail = monitor.readFileDescriptors(pid: pid)
            selectedDetail = detail
        } else {
            selectedDetail = nil
        }
    }

    func toggleSort(_ column: ProcessSortColumn) {
        if sortColumn == column {
            sortAscending.toggle()
        } else {
            sortColumn = column
            sortAscending = column == .name || column == .state
        }
    }

    func toggleExpanded(_ pid: Int32) {
        if expandedPids.contains(pid) {
            expandedPids.remove(pid)
        } else {
            expandedPids.insert(pid)
        }
    }

    func sampleProcess(_ pid: Int32) {
        guard !isSampling else { return }
        isSampling = true
        sampleOutput = nil

        Task.detached { [weak self] in
            let process = Process()
            let pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/sample")
            process.arguments = ["\(pid)", "3"]
            process.standardOutput = pipe
            process.standardError = pipe

            var output = ""
            do {
                try process.run()
                process.waitUntilExit()
                let data = pipe.fileHandleForReading.readDataToEndOfFile()
                output = String(data: data, encoding: .utf8) ?? "No output"
            } catch {
                output = "Failed to sample: \(error.localizedDescription)"
            }

            // Cap output length
            if output.count > 10000 {
                output = String(output.prefix(10000)) + "\n... (truncated)"
            }

            let finalOutput = output
            await MainActor.run { [weak self] in
                self?.sampleOutput = finalOutput
                self?.isSampling = false
            }
        }
    }

    func killProcess(_ pid: Int32) {
        kill(pid, SIGTERM)
    }

    func forceKillProcess(_ pid: Int32) {
        kill(pid, SIGKILL)
    }

    private var sortComparator: (ProcessEntry, ProcessEntry) -> Bool {
        { [sortColumn, sortAscending] a, b in
            let comparison: Bool
            switch sortColumn {
            case .name: comparison = a.name.lowercased() < b.name.lowercased()
            case .pid: comparison = a.pid < b.pid
            case .cpu: comparison = a.cpuUsage < b.cpuUsage
            case .memory: comparison = a.memoryBytes < b.memoryBytes
            case .energy: comparison = a.energyImpact < b.energyImpact
            case .disk: comparison = (a.diskReadBytesPerSec + a.diskWriteBytesPerSec) < (b.diskReadBytesPerSec + b.diskWriteBytesPerSec)
            case .connections: comparison = a.connectionCount < b.connectionCount
            case .threads: comparison = a.threadCount < b.threadCount
            case .state: comparison = a.state.rawValue < b.state.rawValue
            }
            return sortAscending ? comparison : !comparison
        }
    }
}
