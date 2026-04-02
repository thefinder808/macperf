import Foundation

enum Formatters {
    /// Format bytes to human-readable: "48.0 GB", "512 MB", "12.3 KB"
    static func formatBytes(_ bytes: UInt64) -> String {
        let units = ["B", "KB", "MB", "GB", "TB"]
        var value = Double(bytes)
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return "\(bytes) B"
        }
        return String(format: value >= 100 ? "%.0f %@" : "%.1f %@", value, units[unitIndex])
    }

    /// Format bytes to human-readable from Double
    static func formatBytes(_ bytes: Double) -> String {
        formatBytes(UInt64(max(0, bytes)))
    }

    /// Format bytes per second: "1.2 MB/s", "340 KB/s"
    static func formatBytesPerSec(_ bps: Double) -> String {
        let units = ["B/s", "KB/s", "MB/s", "GB/s"]
        var value = bps
        var unitIndex = 0
        while value >= 1024 && unitIndex < units.count - 1 {
            value /= 1024
            unitIndex += 1
        }
        if unitIndex == 0 {
            return String(format: "%.0f %@", value, units[unitIndex])
        }
        return String(format: value >= 100 ? "%.0f %@" : "%.1f %@", value, units[unitIndex])
    }

    /// Format percentage: "23.4%"
    static func formatPercentage(_ pct: Double, decimals: Int = 1) -> String {
        String(format: "%.\(decimals)f%%", pct)
    }

    /// Format integer with locale grouping: "1,234"
    static func formatCount(_ count: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        return formatter.string(from: NSNumber(value: count)) ?? "\(count)"
    }

    /// Format temperature: "62°C"
    static func formatTemperature(_ celsius: Double) -> String {
        String(format: "%.0f°C", celsius)
    }

    /// Format frequency: "3.2 GHz", "1200 MHz"
    static func formatFrequency(_ mhz: Double) -> String {
        if mhz >= 1000 {
            return String(format: "%.1f GHz", mhz / 1000)
        }
        return String(format: "%.0f MHz", mhz)
    }

    /// Format RPM: "1,800 RPM"
    static func formatRPM(_ rpm: Double) -> String {
        "\(formatCount(Int(rpm))) RPM"
    }
}
