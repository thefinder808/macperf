import Foundation

struct TimeSeriesPoint: Identifiable {
    let id = UUID()
    let timestamp: Date
    let value: Double
}

final class TimeSeries: ObservableObject {
    @Published private(set) var points: [TimeSeriesPoint] = []

    /// Maximum number of points to retain (1 hour at 1s intervals)
    let capacity: Int

    init(capacity: Int = 3600) {
        self.capacity = capacity
    }

    func append(_ value: Double) {
        let point = TimeSeriesPoint(timestamp: Date(), value: value)
        points.append(point)
        if points.count > capacity {
            points.removeFirst(points.count - capacity)
        }
    }

    /// Returns the most recent `count` points for display
    func recent(_ count: Int) -> [TimeSeriesPoint] {
        if points.count <= count {
            return points
        }
        return Array(points.suffix(count))
    }

    /// Returns points for a given time range
    func points(for range: TimeRange) -> [TimeSeriesPoint] {
        recent(range.seconds)
    }

    /// The most recent value, or 0 if empty
    var currentValue: Double {
        points.last?.value ?? 0
    }

    /// Peak value across all stored points
    var peakValue: Double {
        points.map(\.value).max() ?? 0
    }

    /// Average value across all stored points
    var averageValue: Double {
        guard !points.isEmpty else { return 0 }
        return points.map(\.value).reduce(0, +) / Double(points.count)
    }

    func clear() {
        points.removeAll()
    }
}
