import SwiftUI
import Combine

final class NetworkViewModel: ObservableObject {
    let monitor = NetworkMonitor()

    let downloadSeries = TimeSeries()
    let uploadSeries = TimeSeries()

    @Published var downloadBytesPerSec: Double = 0
    @Published var uploadBytesPerSec: Double = 0
    @Published var totalDownloaded: UInt64 = 0
    @Published var totalUploaded: UInt64 = 0
    @Published var activeInterface: String = "—"

    func update() {
        let sample = monitor.sample()
        downloadBytesPerSec = sample.downloadBytesPerSec
        uploadBytesPerSec = sample.uploadBytesPerSec
        totalDownloaded = sample.totalDownloaded
        totalUploaded = sample.totalUploaded
        activeInterface = sample.activeInterface

        downloadSeries.append(sample.downloadBytesPerSec)
        uploadSeries.append(sample.uploadBytesPerSec)
    }
}
