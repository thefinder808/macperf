import SwiftUI
import Combine

final class MemoryViewModel: ObservableObject {
    let monitor = MemoryMonitor()

    let usageSeries = TimeSeries()
    let pressureSeries = TimeSeries()

    @Published var totalBytes: UInt64 = 0
    @Published var usedBytes: UInt64 = 0
    @Published var appBytes: UInt64 = 0
    @Published var wiredBytes: UInt64 = 0
    @Published var compressedBytes: UInt64 = 0
    @Published var cachedBytes: UInt64 = 0
    @Published var freeBytes: UInt64 = 0
    @Published var swapUsedBytes: UInt64 = 0
    @Published var pressurePercent: Double = 0
    @Published var pressureLevel: MemoryMonitor.PressureLevel = .normal

    func update() {
        let sample = monitor.sample()
        totalBytes = sample.totalBytes
        usedBytes = sample.usedBytes
        appBytes = sample.appBytes
        wiredBytes = sample.wiredBytes
        compressedBytes = sample.compressedBytes
        cachedBytes = sample.cachedBytes
        freeBytes = sample.freeBytes
        swapUsedBytes = sample.swapUsedBytes
        pressurePercent = sample.pressurePercent
        pressureLevel = sample.pressureLevel

        let usagePercent = totalBytes > 0 ? Double(usedBytes) / Double(totalBytes) * 100 : 0
        usageSeries.append(usagePercent)
        pressureSeries.append(sample.pressurePercent)
    }
}
