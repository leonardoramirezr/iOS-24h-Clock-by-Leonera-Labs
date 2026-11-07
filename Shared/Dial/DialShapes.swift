import SwiftUI

/// A sector of the dial between two hours: a pie wedge, or a ring segment when `innerRadius > 0`.
/// Radii are fractions of the dial radius. The arc is sampled every two degrees.
struct DialSectorShape: Shape {
    var startHour: Double
    var endHour: Double
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    /// The hour at the top of the dial (see `DialGeometry`).
    var topHour: Double = 0

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let span = max(endHour - startHour, 0)
        let steps = max(2, Int((span / 24 * 180).rounded(.up)))
        var path = Path()
        for step in 0...steps {
            let hour = startHour + span * Double(step) / Double(steps)
            let point = DialGeometry.point(hour: hour, radius: radius * outerRadius, center: center, topHour: topHour)
            if step == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        if innerRadius <= 0.001 {
            path.addLine(to: center)
        } else {
            for step in stride(from: steps, through: 0, by: -1) {
                let hour = startHour + span * Double(step) / Double(steps)
                path.addLine(to: DialGeometry.point(
                    hour: hour,
                    radius: radius * innerRadius,
                    center: center,
                    topHour: topHour
                ))
            }
        }
        path.closeSubpath()
        return path
    }
}

/// Evenly spaced radial tick marks. Radii are fractions of the dial radius.
struct DialTicksShape: Shape {
    var count: Int
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    /// Leaves out every tick whose index is a multiple of this value (0 keeps all of them).
    var skipping: Int = 0
    /// The hour at the top of the dial (see `DialGeometry`).
    var topHour: Double = 0

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        for index in 0..<count {
            if skipping > 0 && index % skipping == 0 { continue }
            let hour = Double(index) * 24 / Double(count)
            path.move(to: DialGeometry.point(hour: hour, radius: radius * innerRadius, center: center, topHour: topHour))
            path.addLine(to: DialGeometry.point(hour: hour, radius: radius * outerRadius, center: center, topHour: topHour))
        }
        return path
    }
}

/// A line from the center of the dial towards `hour`.
struct DialHandShape: Shape {
    var hour: Double
    var length: CGFloat
    /// The hour at the top of the dial (see `DialGeometry`).
    var topHour: Double = 0

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: center)
        path.addLine(to: DialGeometry.point(hour: hour, radius: radius * length, center: center, topHour: topHour))
        return path
    }
}

/// A straight line along the radius at `hour`, between two radii (fractions of the dial radius).
struct DialRadialLineShape: Shape {
    var hour: Double
    var innerRadius: CGFloat
    var outerRadius: CGFloat
    /// The hour at the top of the dial (see `DialGeometry`).
    var topHour: Double = 0

    func path(in rect: CGRect) -> Path {
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()
        path.move(to: DialGeometry.point(hour: hour, radius: radius * innerRadius, center: center, topHour: topHour))
        path.addLine(to: DialGeometry.point(hour: hour, radius: radius * outerRadius, center: center, topHour: topHour))
        return path
    }
}
