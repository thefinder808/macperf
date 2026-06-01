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

    /// `appendHistory: false` updates the live values for the menu bar but skips
    /// the chart series — used when the window is hidden so charts don't re-render.
    func update(appendHistory: Bool = true) {
        let sample = monitor.sample()
        overallUsage = sample.overallUsage
        userUsage = sample.userUsage
        systemUsage = sample.systemUsage
        idleUsage = sample.idleUsage
        perCoreUsages = sample.perCoreUsages

        guard appendHistory else { return }
        overallSeries.append(sample.overallUsage)
        userSeries.append(sample.userUsage)
        systemSeries.append(sample.systemUsage)
    }
}
