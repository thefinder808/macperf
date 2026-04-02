import SwiftUI

struct MiniSparkline: View {
    @ObservedObject var series: TimeSeries
    let color: Color
    var pointCount: Int = 60

    var body: some View {
        Canvas { context, size in
            let points = series.recent(pointCount)
            guard points.count >= 2 else { return }

            let maxVal = max(points.map(\.value).max() ?? 1, 1)
            let w = size.width
            let h = size.height
            let step = w / CGFloat(pointCount - 1)

            var path = Path()
            for (i, point) in points.enumerated() {
                let offsetIndex = pointCount - points.count + i
                let x = CGFloat(offsetIndex) * step
                let y = h - (point.value / maxVal) * h
                if i == 0 {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }

            // Stroke the line
            context.stroke(path, with: .color(color), lineWidth: 1.5)

            // Fill area under the line
            var fillPath = path
            let lastIndex = pointCount - 1
            fillPath.addLine(to: CGPoint(x: CGFloat(lastIndex) * step, y: h))
            let firstOffsetIndex = pointCount - points.count
            fillPath.addLine(to: CGPoint(x: CGFloat(firstOffsetIndex) * step, y: h))
            fillPath.closeSubpath()

            let gradient = Gradient(colors: [color.opacity(0.3), color.opacity(0.05)])
            context.fill(
                fillPath,
                with: .linearGradient(gradient, startPoint: .zero, endPoint: CGPoint(x: 0, y: h))
            )
        }
    }
}
