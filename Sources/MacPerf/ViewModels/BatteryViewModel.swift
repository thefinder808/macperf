import SwiftUI
import Combine

final class BatteryViewModel: ObservableObject {
    let monitor = BatteryMonitor()

    let chargeSeries = TimeSeries()

    @Published var isPresent: Bool = false
    @Published var currentPercent: Double = 0
    @Published var maxCapacity: Int = 0
    @Published var designCapacity: Int = 0
    @Published var cycleCount: Int = 0
    @Published var temperature: Double = 0
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var voltage: Double = 0
    @Published var amperage: Double = 0
    @Published var timeRemaining: Int = 0
    @Published var healthPercent: Double = 0

    func update() {
        let sample = monitor.sample()
        isPresent = sample.isPresent
        currentPercent = sample.currentPercent
        maxCapacity = sample.maxCapacity
        designCapacity = sample.designCapacity
        cycleCount = sample.cycleCount
        temperature = sample.temperature
        isCharging = sample.isCharging
        isPluggedIn = sample.isPluggedIn
        voltage = sample.voltage
        amperage = sample.amperage
        timeRemaining = sample.timeRemaining
        healthPercent = sample.healthPercent

        if sample.isPresent {
            chargeSeries.append(sample.currentPercent)
        }
    }
}
