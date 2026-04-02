import SwiftUI
import Combine

final class StorageViewModel: ObservableObject {
    let monitor = StorageMonitor()

    @Published var volumes: [StorageMonitor.VolumeInfo] = []

    func update() {
        let sample = monitor.sample()
        volumes = sample.volumes
    }
}
