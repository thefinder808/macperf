import SwiftUI
import Combine

final class DiskViewModel: ObservableObject {
    let monitor = DiskMonitor()

    let readSeries = TimeSeries()
    let writeSeries = TimeSeries()

    @Published var readBytesPerSec: Double = 0
    @Published var writeBytesPerSec: Double = 0
    @Published var readOpsPerSec: Double = 0
    @Published var writeOpsPerSec: Double = 0
    @Published var totalBytesRead: UInt64 = 0
    @Published var totalBytesWritten: UInt64 = 0

    func update(appendHistory: Bool = true) {
        let sample = monitor.sample()
        readBytesPerSec = sample.readBytesPerSec
        writeBytesPerSec = sample.writeBytesPerSec
        readOpsPerSec = sample.readOpsPerSec
        writeOpsPerSec = sample.writeOpsPerSec
        totalBytesRead = sample.totalBytesRead
        totalBytesWritten = sample.totalBytesWritten

        guard appendHistory else { return }
        readSeries.append(sample.readBytesPerSec)
        writeSeries.append(sample.writeBytesPerSec)
    }
}
