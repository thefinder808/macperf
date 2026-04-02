import Foundation
import IOKit

final class DiskMonitor {
    struct Sample {
        let readBytesPerSec: Double
        let writeBytesPerSec: Double
        let readOpsPerSec: Double
        let writeOpsPerSec: Double
        let totalBytesRead: UInt64
        let totalBytesWritten: UInt64
    }

    private var previousReadBytes: UInt64 = 0
    private var previousWriteBytes: UInt64 = 0
    private var previousReadOps: UInt64 = 0
    private var previousWriteOps: UInt64 = 0
    private var previousTimestamp: Date?

    func sample() -> Sample {
        var totalRead: UInt64 = 0
        var totalWrite: UInt64 = 0
        var totalReadOps: UInt64 = 0
        var totalWriteOps: UInt64 = 0

        var iter: io_iterator_t = 0
        let matching = IOServiceMatching("IOBlockStorageDriver")
        let result = IOServiceGetMatchingServices(kIOMainPortDefault, matching, &iter)

        if result == KERN_SUCCESS {
            var entry: io_registry_entry_t = IOIteratorNext(iter)
            while entry != 0 {
                defer {
                    IOObjectRelease(entry)
                    entry = IOIteratorNext(iter)
                }

                var props: Unmanaged<CFMutableDictionary>?
                guard IORegistryEntryCreateCFProperties(entry, &props, kCFAllocatorDefault, 0) == KERN_SUCCESS,
                      let dict = props?.takeRetainedValue() as? [String: Any],
                      let stats = dict["Statistics"] as? [String: Any] else {
                    continue
                }

                if let rb = stats["Bytes (Read)"] as? UInt64 { totalRead += rb }
                if let wb = stats["Bytes (Write)"] as? UInt64 { totalWrite += wb }
                if let ro = stats["Operations (Read)"] as? UInt64 { totalReadOps += ro }
                if let wo = stats["Operations (Write)"] as? UInt64 { totalWriteOps += wo }
            }
            IOObjectRelease(iter)
        }

        let now = Date()
        let elapsed: Double
        if let prev = previousTimestamp {
            elapsed = now.timeIntervalSince(prev)
        } else {
            elapsed = 0
        }

        let readRate: Double
        let writeRate: Double
        let readOpsRate: Double
        let writeOpsRate: Double

        if elapsed > 0 && previousTimestamp != nil {
            readRate = totalRead >= previousReadBytes ? Double(totalRead - previousReadBytes) / elapsed : 0
            writeRate = totalWrite >= previousWriteBytes ? Double(totalWrite - previousWriteBytes) / elapsed : 0
            readOpsRate = totalReadOps >= previousReadOps ? Double(totalReadOps - previousReadOps) / elapsed : 0
            writeOpsRate = totalWriteOps >= previousWriteOps ? Double(totalWriteOps - previousWriteOps) / elapsed : 0
        } else {
            readRate = 0
            writeRate = 0
            readOpsRate = 0
            writeOpsRate = 0
        }

        previousReadBytes = totalRead
        previousWriteBytes = totalWrite
        previousReadOps = totalReadOps
        previousWriteOps = totalWriteOps
        previousTimestamp = now

        return Sample(
            readBytesPerSec: max(0, readRate),
            writeBytesPerSec: max(0, writeRate),
            readOpsPerSec: max(0, readOpsRate),
            writeOpsPerSec: max(0, writeOpsRate),
            totalBytesRead: totalRead,
            totalBytesWritten: totalWrite
        )
    }
}
