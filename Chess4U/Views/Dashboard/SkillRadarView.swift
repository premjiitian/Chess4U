import SwiftUI

struct SkillRadarView: View {
    let profile: PlayerProfile

    private let skills: [(String, Double)] = []
    private let axes = ["Tactics", "Openings", "Endgames", "Calculation", "Strategy"]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "chart.xyaxis.line")
                    .foregroundColor(.blue)
                Text("Skill Radar")
                    .font(.headline)
                Spacer()
                Text("Based on training")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)

            ZStack {
                RadarBackground(axes: axes)
                RadarShape(values: skillValues, axes: axes)
                    .fill(Color.blue.opacity(0.25))
                    .overlay(
                        RadarShape(values: skillValues, axes: axes)
                            .stroke(Color.blue, lineWidth: 2)
                    )
                AxisLabels(values: skillValues, axes: axes)
            }
            .frame(height: 160)
            .padding()
        }
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }

    private var skillValues: [Double] {
        [
            min(profile.tacticsAccuracy / 100, 1.0),
            min(profile.openingAccuracy / 100, 1.0),
            min(profile.endgameAccuracy / 100, 1.0),
            min(profile.calculationScore / 100, 1.0),
            min(profile.strategyScore / 100, 1.0)
        ]
    }
}

struct RadarBackground: View {
    let axes: [String]
    let rings = 4

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 - 10

            ZStack {
                ForEach(1...rings, id: \.self) { ring in
                    let r = radius * Double(ring) / Double(rings)
                    radarPolygon(center: center, radius: r, sides: axes.count)
                        .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }

                ForEach(axes.indices, id: \.self) { idx in
                    let angle = angle(for: idx, count: axes.count)
                    Path { path in
                        path.move(to: center)
                        path.addLine(to: pointOnCircle(center: center, radius: radius, angle: angle))
                    }
                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                }
            }
        }
    }

    private func radarPolygon(center: CGPoint, radius: Double, sides: Int) -> Path {
        var path = Path()
        for i in 0..<sides {
            let angle = angle(for: i, count: sides)
            let point = pointOnCircle(center: center, radius: radius, angle: angle)
            if i == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }

    private func angle(for index: Int, count: Int) -> Double {
        Double(index) * 2 * .pi / Double(count) - .pi / 2
    }

    private func pointOnCircle(center: CGPoint, radius: Double, angle: Double) -> CGPoint {
        CGPoint(x: center.x + radius * cos(angle),
                y: center.y + radius * sin(angle))
    }
}

struct RadarShape: Shape {
    let values: [Double]
    let axes: [String]

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2 - 10
        var path = Path()

        for (i, value) in values.enumerated() {
            let angle = Double(i) * 2 * .pi / Double(values.count) - .pi / 2
            let r = radius * max(0.05, value)
            let point = CGPoint(x: center.x + r * cos(CGFloat(angle)),
                                y: center.y + r * sin(CGFloat(angle)))
            if i == 0 { path.move(to: point) }
            else { path.addLine(to: point) }
        }
        path.closeSubpath()
        return path
    }
}

struct AxisLabels: View {
    let values: [Double]
    let axes: [String]

    var body: some View {
        GeometryReader { geo in
            let center = CGPoint(x: geo.size.width / 2, y: geo.size.height / 2)
            let radius = min(geo.size.width, geo.size.height) / 2 + 2

            ForEach(axes.indices, id: \.self) { idx in
                let angle = Double(idx) * 2 * .pi / Double(axes.count) - .pi / 2
                let x = center.x + radius * cos(angle)
                let y = center.y + radius * sin(angle)

                VStack(spacing: 2) {
                    Text(axes[idx])
                        .font(.system(size: 8, weight: .medium))
                        .multilineTextAlignment(.center)
                    Text("\(Int(values[idx] * 100))%")
                        .font(.system(size: 7))
                        .foregroundColor(.blue)
                }
                .position(x: x, y: y)
            }
        }
    }
}
