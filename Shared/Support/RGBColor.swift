import SwiftUI

/// A plain sRGB color that can be interpolated, used to build the sky gradient.
struct RGBColor: Hashable {
    var red: Double
    var green: Double
    var blue: Double

    init(red: Double, green: Double, blue: Double) {
        self.red = red
        self.green = green
        self.blue = blue
    }

    /// Creates a color from a hexadecimal value such as `0xFF8800`.
    init(hex: UInt32) {
        self.init(
            red: Double((hex >> 16) & 0xFF) / 255,
            green: Double((hex >> 8) & 0xFF) / 255,
            blue: Double(hex & 0xFF) / 255
        )
    }

    /// Converts a Core Graphics color (for example the color of a calendar) to sRGB.
    init?(cgColor: CGColor) {
        guard let space = CGColorSpace(name: CGColorSpace.sRGB),
              let converted = cgColor.converted(to: space, intent: .defaultIntent, options: nil),
              let components = converted.components,
              components.count >= 3 else { return nil }
        func clamped(_ value: CGFloat) -> Double { min(max(Double(value), 0), 1) }
        self.init(red: clamped(components[0]), green: clamped(components[1]), blue: clamped(components[2]))
    }

    /// Linear interpolation towards `other`; `amount` is clamped to `0...1`.
    func mixed(with other: RGBColor, amount: Double) -> RGBColor {
        let progress = min(max(amount, 0), 1)
        return RGBColor(
            red: red + (other.red - red) * progress,
            green: green + (other.green - green) * progress,
            blue: blue + (other.blue - blue) * progress
        )
    }

    /// Approximate relative luminance.
    var luminance: Double {
        0.2126 * red + 0.7152 * green + 0.0722 * blue
    }

    var color: Color {
        Color(red: red, green: green, blue: blue)
    }
}
