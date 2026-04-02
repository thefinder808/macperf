import SwiftUI
import Combine

final class CPUViewModel: ObservableObject {
    let monitor = CPUMonitor()

    let overallSeries = TimeSeries()
    let userSeries = TimeSeries()
    let systemSeries = TimeSeries()

    @Published var overallUsage: Double = 0
    @Published var userUsage: Double = 0
    @Published var systemUsage: Double = 0
    @Published var idleUsage: Double = 100
    @Published var perCoreUsages: [Double] = []

    func update() {
        let sample = monitor.sample()
        overallUsage = sample.overallUsage
        userUsage = sample.userUsage
        systemUsage = sample.systemUsage
        idleUsage = sample.idleUsage
        perCoreUsages = sample.perCoreUsages

        overallSeries.append(sample.overallUsage)
        userSeries.append(sample.userUsage)
        systemSeries.append(sample.systemUsage)
    }
}
