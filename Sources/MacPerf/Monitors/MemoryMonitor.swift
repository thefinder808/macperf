import Foundation
import Darwin

final class MemoryMonitor {
    struct Sample {
        let totalBytes: UInt64
        let usedBytes: UInt64
        let appBytes: UInt64       // active (internal + external)
        let wiredBytes: UInt64
        let compressedBytes: UInt64
        let cachedBytes: UInt64    // inactive + purgeable
        let freeBytes: UInt64
        let swapUsedBytes: UInt64
        let pressurePercent: Double  // used / total * 100
        let pressureLevel: PressureLevel
    }

    enum PressureLevel: String {
        case normal = "Normal"
        case warning = "Warning"
        case critical = "Critical"
    }

    private let pageSize: UInt64
    private let totalRAM: UInt64

    init() {
        self.pageSize = UInt64(vm_kernel_page_size)
        var memsize: UInt64 = 0
        var size = MemoryLayout<UInt64>.size
        sysctlbyname("hw.memsize", &memsize, &size, nil, 0)
        self.totalRAM = memsize
    }

    func sample() -> Sample {
        var vmStats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &vmStats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        guard result == KERN_SUCCESS else {
            return emptySample()
        }

        let active = UInt64(vmStats.active_count) * pageSize
        let wired = UInt64(vmStats.wire_count) * pageSize
        let compressed = UInt64(vmStats.compressor_page_count) * pageSize
        let inactive = UInt64(vmStats.inactive_count) * pageSize
        let purgeable = UInt64(vmStats.purgeable_count) * pageSize
        let free = UInt64(vmStats.free_count) * pageSize
        let speculative = UInt64(vmStats.speculative_count) * pageSize

        let cached = inactive + purgeable
        let appMemory = active
        let used = active + wired + compressed

        // Swap usage via sysctl
        let swapUsed = readSwapUsage()

        // Pressure level comes from the kernel — same signal Activity Monitor uses
        // for its gauge color and what DispatchSource.makeMemoryPressureSource fires on.
        let level = readKernelPressureLevel()

        // Continuous gauge value, band-anchored to the kernel level so the gauge's
        // color thresholds (green <50, yellow 50–75, red ≥75 in PressureGauge) stay
        // in sync with `level`. Within each band, motion is driven by compression
        // and swap activity for a smooth animation.
        let compressedRatio = totalRAM > 0 ? Double(compressed) / Double(totalRAM) : 0
        let swapRatio = totalRAM > 0 ? Double(swapUsed) / Double(totalRAM) : 0
        let activity = compressedRatio + swapRatio
        let pressure: Double = {
            switch level {
            case .normal:   return min(49.5, activity * 200)
            case .warning:  return 50 + min(24.5, activity * 80)
            case .critical: return 75 + min(25, activity * 60)
            }
        }()

        return Sample(
            totalBytes: totalRAM,
            usedBytes: used,
            appBytes: appMemory,
            wiredBytes: wired,
            compressedBytes: compressed,
            cachedBytes: cached,
            freeBytes: free + speculative,
            swapUsedBytes: swapUsed,
            pressurePercent: pressure,
            pressureLevel: level
        )
    }

    private func readSwapUsage() -> UInt64 {
        var swapUsage = xsw_usage()
        var size = MemoryLayout<xsw_usage>.size
        let result = sysctlbyname("vm.swapusage", &swapUsage, &size, nil, 0)
        guard result == 0 else { return 0 }
        return swapUsage.xsu_used
    }

    private func readKernelPressureLevel() -> PressureLevel {
        // Values match DISPATCH_MEMORYPRESSURE_*: 1=NORMAL, 2=WARN, 4=CRITICAL.
        var raw: Int32 = 0
        var size = MemoryLayout<Int32>.size
        let result = sysctlbyname("kern.memorystatus_vm_pressure_level", &raw, &size, nil, 0)
        guard result == 0 else { return .normal }
        switch raw {
        case 4: return .critical
        case 2: return .warning
        default: return .normal
        }
    }

    private func emptySample() -> Sample {
        Sample(
            totalBytes: totalRAM,
            usedBytes: 0,
            appBytes: 0,
            wiredBytes: 0,
            compressedBytes: 0,
            cachedBytes: 0,
            freeBytes: totalRAM,
            swapUsedBytes: 0,
            pressurePercent: 0,
            pressureLevel: .normal
        )
    }
}
