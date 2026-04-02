import SwiftUI
import Combine

final class ThermalViewModel: ObservableObject {
    let monitor = ThermalMonitor()

    let cpuTempSeries = TimeSeries()
    let gpuTempSeries = TimeSeries()

    @Published var cpuTemperature: Double = 0
    @Published var gpuTemperature: Double = 0
    @Published var thermalState: ThermalMonitor.ThermalState = .nominal
    @Published var fanSpeeds: [ThermalMonitor.FanReading] = []

    func update() {
        let sample = monitor.sample()
        cpuTemperature = sample.cpuTemperature
        gpuTemperature = sample.gpuTemperature
        thermalState = sample.thermalState
        fanSpeeds = sample.fanSpeeds

        cpuTempSeries.append(sample.cpuTemperature)
        gpuTempSeries.append(sample.gpuTemperature)
    }
}
