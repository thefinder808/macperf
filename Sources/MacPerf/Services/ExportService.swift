import Foundation
import AppKit

enum ExportFormat: String, CaseIterable, Identifiable {
    case csv = "CSV"
    case json = "JSON"

    var id: String { rawValue }
    var fileExtension: String { rawValue.lowercased() }
}

final class ExportService {
    static func export(appState: AppState, format: ExportFormat) {
        let panel = NSSavePanel()
        panel.title = "Export MacPerf Data"
        panel.nameFieldStringValue = "macperf-export.\(format.fileExtension)"
        panel.allowedContentTypes = format == .csv
            ? [.commaSeparatedText]
            : [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        let data: String
        switch format {
        case .csv:
            data = generateCSV(appState: appState)
        case .json:
            data = generateJSON(appState: appState)
        }

        try? data.write(to: url, atomically: true, encoding: .utf8)
    }

    // MARK: - CSV

    private static func generateCSV(appState: AppState) -> String {
        var lines: [String] = []

        // Header
        lines.append("timestamp,cpu_percent,memory_percent,disk_read_bps,disk_write_bps,network_down_bps,network_up_bps,gpu_percent,cpu_temp")

        // Merge data from all series by index
        let cpuPoints = appState.cpuSeries.points
        let memPoints = appState.memorySeries.points
        let diskRPoints = appState.diskReadSeries.points
        let diskWPoints = appState.diskVM.writeSeries.points
        let netDPoints = appState.networkDownSeries.points
        let netUPoints = appState.networkVM.uploadSeries.points
        let gpuPoints = appState.gpuSeries.points
        let tempPoints = appState.thermalSeries.points

        let maxCount = max(cpuPoints.count, memPoints.count, diskRPoints.count, netDPoints.count, gpuPoints.count, tempPoints.count)
        let dateFormatter = ISO8601DateFormatter()

        for i in 0..<maxCount {
            let ts = cpuPoints.indices.contains(i) ? dateFormatter.string(from: cpuPoints[i].timestamp) : ""
            let cpu = cpuPoints.indices.contains(i) ? String(format: "%.2f", cpuPoints[i].value) : ""
            let mem = memPoints.indices.contains(i) ? String(format: "%.2f", memPoints[i].value) : ""
            let diskR = diskRPoints.indices.contains(i) ? String(format: "%.0f", diskRPoints[i].value) : ""
            let diskW = diskWPoints.indices.contains(i) ? String(format: "%.0f", diskWPoints[i].value) : ""
            let netD = netDPoints.indices.contains(i) ? String(format: "%.0f", netDPoints[i].value) : ""
            let netU = netUPoints.indices.contains(i) ? String(format: "%.0f", netUPoints[i].value) : ""
            let gpu = gpuPoints.indices.contains(i) ? String(format: "%.2f", gpuPoints[i].value) : ""
            let temp = tempPoints.indices.contains(i) ? String(format: "%.1f", tempPoints[i].value) : ""

            lines.append("\(ts),\(cpu),\(mem),\(diskR),\(diskW),\(netD),\(netU),\(gpu),\(temp)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - JSON

    private static func generateJSON(appState: AppState) -> String {
        let dateFormatter = ISO8601DateFormatter()

        let snapshot: [String: Any] = [
            "exported_at": dateFormatter.string(from: Date()),
            "system": [
                "cpu_model": appState.systemInfo.cpuModel,
                "total_cores": appState.systemInfo.totalCores,
                "total_ram_bytes": appState.systemInfo.totalRAMBytes,
                "os_version": appState.systemInfo.osVersion,
            ],
            "current": [
                "cpu_percent": round(appState.cpuUsage * 100) / 100,
                "memory_percent": round(appState.memoryUsage * 100) / 100,
                "memory_used_bytes": appState.memoryVM.usedBytes,
                "memory_total_bytes": appState.memoryVM.totalBytes,
                "disk_read_bps": round(appState.diskReadRate),
                "disk_write_bps": round(appState.diskVM.writeBytesPerSec),
                "network_down_bps": round(appState.networkDownRate),
                "network_up_bps": round(appState.networkVM.uploadBytesPerSec),
                "gpu_percent": round(appState.gpuUsage * 100) / 100,
                "cpu_temp_celsius": round(appState.thermalTemp * 10) / 10,
                "thermal_state": appState.thermalVM.thermalState.rawValue,
                "process_count": appState.processVM.processCount,
                "thread_count": appState.processVM.totalThreads,
            ],
            "top_processes": appState.processVM.filteredProcesses.prefix(10).map { proc in
                [
                    "pid": proc.pid,
                    "name": proc.name,
                    "cpu_percent": round(proc.cpuUsage * 100) / 100,
                    "memory_bytes": proc.memoryBytes,
                    "threads": proc.threadCount,
                    "energy": proc.energyImpact.rawValue,
                ] as [String: Any]
            },
        ]

        guard let jsonData = try? JSONSerialization.data(withJSONObject: snapshot, options: [.prettyPrinted, .sortedKeys]),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            return "{\"error\": \"Failed to serialize\"}"
        }

        return jsonString
    }
}
