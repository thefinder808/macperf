import Foundation
import Darwin

struct SystemInfo {
    let cpuModel: String
    let totalCores: Int
    let performanceCores: Int
    let efficiencyCores: Int
    let totalRAMBytes: UInt64
    let pageSize: UInt64
    let gpuName: String
    let osVersion: String
    let hostName: String

    var totalRAMFormatted: String {
        Formatters.formatBytes(totalRAMBytes)
    }

    var coreDescription: String {
        if performanceCores > 0 && efficiencyCores > 0 {
            return "\(performanceCores) Performance + \(efficiencyCores) Efficiency"
        }
        return "\(totalCores) cores"
    }

    static func fetch() -> SystemInfo {
        SystemInfo(
            cpuModel: sysctl(name: "machdep.cpu.brand_string") ?? "Unknown",
            totalCores: sysctlInt(name: "hw.ncpu"),
            performanceCores: sysctlInt(name: "hw.perflevel0.physicalcpu"),
            efficiencyCores: sysctlInt(name: "hw.perflevel1.physicalcpu"),
            totalRAMBytes: sysctlUInt64(name: "hw.memsize"),
            pageSize: UInt64(vm_kernel_page_size),
            gpuName: fetchGPUName(),
            osVersion: ProcessInfo.processInfo.operatingSystemVersionString,
            hostName: ProcessInfo.processInfo.hostName
        )
    }

    // MARK: - sysctl helpers

    private static func sysctl(name: String) -> String? {
        var size = 0
        sysctlbyname(name, nil, &size, nil, 0)
        guard size > 0 else { return nil }
        var buffer = [CChar](repeating: 0, count: size)
        sysctlbyname(name, &buffer, &size, nil, 0)
        return String(cString: buffer)
    }

    private static func sysctlInt(name: String) -> Int {
        var value: Int32 = 0
        var size = MemoryLayout<Int32>.size
        sysctlbyname(name, &value, &size, nil, 0)
        return Int(value)
    }

    private static func sysctlUInt64(name: String) -> UInt64 {
        var value: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname(name, &value, &size, nil, 0)
        return value
    }

    private static func fetchGPUName() -> String {
        // Will be populated by GPUMonitor via IOKit in a later chunk
        // For now, derive from CPU model on Apple Silicon
        let cpu = sysctl(name: "machdep.cpu.brand_string") ?? ""
        if cpu.contains("Apple") {
            // Apple Silicon: GPU name matches the chip name
            return cpu.replacingOccurrences(of: "Apple ", with: "Apple ") // Keep as-is
        }
        return "Unknown GPU"
    }
}
