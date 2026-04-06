import Foundation
import IOKit

final class GPUMonitor {
    struct Sample {
        let deviceUtilization: Double    // 0-100
        let rendererUtilization: Double  // 0-100
        let tilerUtilization: Double     // 0-100
        let allocatedMemory: UInt64      // bytes
        let inUseMemory: UInt64          // bytes
    }

    func sample() -> Sample {
        var iter: io_iterator_t = 0
        let matching = IOServiceMatching("IOAccelerator")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter)

        guard result == KERN_SUCCESS else {
            if iter != 0 { IOObjectRelease(iter) }
            return emptySample()
        }

        defer { IOObjectRelease(iter) }

        var candidates: [Sample] = []
        var entry: io_registry_entry_t = IOIteratorNext(iter)
        while entry != 0 {
            defer {
                IOObjectRelease(entry)
                entry = IOIteratorNext(iter)
            }

            var props: Unmanaged<CFMutableDictionary>?
            guard IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                  let dict = props?.takeRetainedValue() as? [String: Any],
                  let perfStats = dict["PerformanceStatistics"] as? [String: Any] else {
                continue
            }

            let deviceUtil = doubleFromStats(perfStats, key: "Device Utilization %")
            let rendererUtil = doubleFromStats(perfStats, key: "Renderer Utilization %")
            let tilerUtil = doubleFromStats(perfStats, key: "Tiler Utilization %")
            let allocMem = uint64FromStats(perfStats, key: "Alloc system memory")
                        ?? uint64FromStats(perfStats, key: "alloc system memory")
                        ?? 0
            let inUseMem = uint64FromStats(perfStats, key: "In use system memory")
                        ?? uint64FromStats(perfStats, key: "in use system memory")
                        ?? 0

            candidates.append(Sample(
                deviceUtilization: deviceUtil ?? 0,
                rendererUtilization: rendererUtil ?? 0,
                tilerUtilization: tilerUtil ?? 0,
                allocatedMemory: allocMem,
                inUseMemory: inUseMem
            ))
        }

        guard !candidates.isEmpty else { return emptySample() }

        return candidates.max(by: { a, b in
            if a.deviceUtilization != b.deviceUtilization {
                return a.deviceUtilization < b.deviceUtilization
            }
            return a.allocatedMemory < b.allocatedMemory
        })!
    }

    private func doubleFromStats(_ stats: [String: Any], key: String) -> Double? {
        if let val = stats[key] as? NSNumber {
            return val.doubleValue
        }
        return nil
    }

    private func uint64FromStats(_ stats: [String: Any], key: String) -> UInt64? {
        if let val = stats[key] as? NSNumber {
            return val.uint64Value
        }
        return nil
    }

    private func emptySample() -> Sample {
        Sample(deviceUtilization: 0, rendererUtilization: 0, tilerUtilization: 0, allocatedMemory: 0, inUseMemory: 0)
    }
}
