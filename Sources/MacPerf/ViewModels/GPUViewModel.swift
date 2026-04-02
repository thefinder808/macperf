import SwiftUI
import Combine

final class GPUViewModel: ObservableObject {
    let monitor = GPUMonitor()

    let deviceUtilSeries = TimeSeries()

    @Published var deviceUtilization: Double = 0
    @Published var rendererUtilization: Double = 0
    @Published var tilerUtilization: Double = 0
    @Published var allocatedMemory: UInt64 = 0
    @Published var inUseMemory: UInt64 = 0

    func update() {
        let sample = monitor.sample()
        deviceUtilization = sample.deviceUtilization
        rendererUtilization = sample.rendererUtilization
        tilerUtilization = sample.tilerUtilization
        allocatedMemory = sample.allocatedMemory
        inUseMemory = sample.inUseMemory

        deviceUtilSeries.append(sample.deviceUtilization)
    }
}
