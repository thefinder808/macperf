import Foundation
import Darwin

final class NetworkMonitor {
    struct Sample {
        let downloadBytesPerSec: Double
        let uploadBytesPerSec: Double
        let totalDownloaded: UInt64
        let totalUploaded: UInt64
        let activeInterface: String
    }

    private var previousDownBytes: UInt64 = 0
    private var previousUpBytes: UInt64 = 0
    private var previousTimestamp: Date?

    func sample() -> Sample {
        var totalDown: UInt64 = 0
        var totalUp: UInt64 = 0
        var bestInterface = "en0"
        var bestTraffic: UInt64 = 0

        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else {
            return emptySample()
        }
        defer { freeifaddrs(ifaddr) }

        var current: UnsafeMutablePointer<ifaddrs>? = firstAddr
        while let addr = current {
            defer { current = addr.pointee.ifa_next }

            // Only look at AF_LINK (link-layer) entries for byte counters
            guard addr.pointee.ifa_addr.pointee.sa_family == UInt8(AF_LINK) else { continue }

            let name = String(cString: addr.pointee.ifa_name)

            // Skip loopback
            guard !name.hasPrefix("lo") else { continue }

            // Get interface data
            guard let data = addr.pointee.ifa_data else { continue }
            let ifData = data.assumingMemoryBound(to: if_data.self).pointee

            let ibytes = UInt64(ifData.ifi_ibytes)
            let obytes = UInt64(ifData.ifi_obytes)
            totalDown += ibytes
            totalUp += obytes

            let traffic = ibytes + obytes
            if traffic > bestTraffic {
                bestTraffic = traffic
                bestInterface = name
            }
        }

        let now = Date()
        let elapsed: Double
        if let prev = previousTimestamp {
            elapsed = now.timeIntervalSince(prev)
        } else {
            elapsed = 0
        }

        let downRate: Double
        let upRate: Double

        if elapsed > 0 && previousTimestamp != nil {
            downRate = totalDown >= previousDownBytes ? Double(totalDown - previousDownBytes) / elapsed : 0
            upRate = totalUp >= previousUpBytes ? Double(totalUp - previousUpBytes) / elapsed : 0
        } else {
            downRate = 0
            upRate = 0
        }

        previousDownBytes = totalDown
        previousUpBytes = totalUp
        previousTimestamp = now

        return Sample(
            downloadBytesPerSec: max(0, downRate),
            uploadBytesPerSec: max(0, upRate),
            totalDownloaded: totalDown,
            totalUploaded: totalUp,
            activeInterface: bestInterface
        )
    }

    private func emptySample() -> Sample {
        Sample(downloadBytesPerSec: 0, uploadBytesPerSec: 0, totalDownloaded: 0, totalUploaded: 0, activeInterface: "—")
    }
}
