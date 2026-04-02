import SwiftUI

struct PressureGauge: View {
    let value: Double // 0-100
    let level: MemoryMonitor.PressureLevel

    @EnvironmentObject var themeManager: ThemeManager
    @State private var animatedValue: Double = 0
    @State private var glowRadius: CGFloat = 4

    private let startAngle = Angle.degrees(135)
    private let endAngle = Angle.degrees(405)

    var body: some View {
        let theme = themeManager.current

        VStack(spacing: 4) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let center = CGPoint(x: w / 2, y: h * 0.6)
                let radius = min(w, h) * 0.42
                let needleLen = radius * 0.7

                ZStack {
                    // Track
                    arcPath(center: center, radius: radius, from: 0, to: 1)
                        .stroke(theme.trackBackground, style: StrokeStyle(lineWidth: max(6, radius * 0.16), lineCap: .round))

                    // Green segment (0-50%)
                    if animatedValue > 0 {
                        arcPath(center: center, radius: radius, from: 0, to: min(animatedValue / 100, 0.5))
                            .stroke(Color.green, style: StrokeStyle(lineWidth: max(6, radius * 0.16), lineCap: .round))
                            .shadow(color: theme.glowEnabled ? .green.opacity(0.5) : .clear, radius: 6)
                    }

                    // Yellow segment (50-75%)
                    if animatedValue > 50 {
                        arcPath(center: center, radius: radius, from: 0.5, to: min(animatedValue / 100, 0.75))
                            .stroke(Color.yellow, style: StrokeStyle(lineWidth: max(6, radius * 0.16), lineCap: .round))
                            .shadow(color: theme.glowEnabled ? .yellow.opacity(0.5) : .clear, radius: 6)
                    }

                    // Red segment (75-100%)
                    if animatedValue > 75 {
                        arcPath(center: center, radius: radius, from: 0.75, to: min(animatedValue / 100, 1.0))
                            .stroke(Color.red, style: StrokeStyle(lineWidth: max(6, radius * 0.16), lineCap: .round))
                            .shadow(color: theme.glowEnabled ? .red.opacity(0.5) : .clear, radius: 6)
                    }

                    // Needle
                    let totalSweep = endAngle - startAngle
                    let needleAngle = startAngle + totalSweep * (animatedValue / 100)
                    let tipX = center.x + needleLen * CGFloat(cos(needleAngle.radians))
                    let tipY = center.y + needleLen * CGFloat(sin(needleAngle.radians))

                    Path { path in
                        path.move(to: center)
                        path.addLine(to: CGPoint(x: tipX, y: tipY))
                    }
                    .stroke(levelColor, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                    .shadow(
                        color: theme.glowEnabled ? levelColor.opacity(0.5) : .clear,
                        radius: glowRadius
                    )

                    Circle()
                        .fill(levelColor)
                        .frame(width: 6, height: 6)
                        .position(center)
                }
            }
            .aspectRatio(1.6, contentMode: .fit)

            Text(level.rawValue)
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(levelColor)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                animatedValue = value
            }
            if themeManager.current.glowEnabled {
                withAnimation(.easeInOut(duration: 2).repeatForever(autoreverses: true)) {
                    glowRadius = 8
                }
            }
        }
        .onChange(of: value) { _, newValue in
            withAnimation(.spring(response: 0.8, dampingFraction: 0.6)) {
                animatedValue = newValue
            }
        }
    }

    private func arcPath(center: CGPoint, radius: CGFloat, from: Double, to: Double) -> Path {
        let totalSweep = endAngle - startAngle
        let start = startAngle + totalSweep * from
        let end = startAngle + totalSweep * to

        return Path { path in
            path.addArc(
                center: center,
                radius: radius,
                startAngle: start,
                endAngle: end,
                clockwise: false
            )
        }
    }

    private var levelColor: Color {
        switch level {
        case .normal: return .green
        case .warning: return .yellow
        case .critical: return .red
        }
    }
}
