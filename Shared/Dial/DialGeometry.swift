import CoreGraphics
import Foundation

/// Converts between hours and positions on the dial.
/// Hour 0 (24) is at the top, 6 on the right, 12 at the bottom and 18 on the left.
enum DialGeometry {
    static func radians(forHour hour: Double) -> Double {
        hour / 24 * 2 * Double.pi
    }

    /// The point at `hour` on a circle of `radius` around `center` (SwiftUI coordinates, y down).
    static func point(hour: Double, radius: CGFloat, center: CGPoint) -> CGPoint {
        let angle = radians(forHour: hour)
        let x = center.x + radius * CGFloat(sin(angle))
        let y = center.y - radius * CGFloat(cos(angle))
        return CGPoint(x: x, y: y)
    }

    /// The hour (`0..<24`) and the distance from the center (as a fraction of `radius`) of a point.
    static func polar(of point: CGPoint, center: CGPoint, radius: CGFloat) -> (hour: Double, distance: CGFloat) {
        let dx = Double(point.x - center.x)
        let dy = Double(point.y - center.y)
        var angle = atan2(dx, -dy)
        if angle < 0 { angle += 2 * Double.pi }
        let distance = CGFloat(hypot(dx, dy)) / max(radius, 1)
        return (angle / (2 * Double.pi) * 24, distance)
    }
}
