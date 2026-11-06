import SwiftUI

/// Colors of the dial: dark for night hours, light for day hours, warm blend at twilight.
enum SkyPalette {
    static let night = RGBColor(hex: 0x0E1433)
    static let day = RGBColor(hex: 0xDCEBFA)
    static let twilight = RGBColor(hex: 0xF79A5E)
    /// Text and ticks drawn over night hours.
    static let nightInk = RGBColor(hex: 0xEEF1FA)
    /// Text and ticks drawn over day hours.
    static let dayInk = RGBColor(hex: 0x1D2547)
    static let hand = RGBColor(hex: 0xFF5A36)
    static let sun = RGBColor(hex: 0xF9B934)
    static let moon = RGBColor(hex: 0xD9E0FF)

    /// Sky color at a given hour.
    static func sky(atHour hour: Double, daylight: Daylight) -> RGBColor {
        let base = night.mixed(with: day, amount: daylight.brightness(atHour: hour))
        return base.mixed(with: twilight, amount: daylight.twilightIntensity(atHour: hour) * 0.65)
    }

    /// Readable text color over the sky at a given hour.
    static func ink(atHour hour: Double, daylight: Daylight) -> RGBColor {
        daylight.brightness(atHour: hour) > 0.5 ? dayInk : nightInk
    }

    /// Sky gradient around the dial, starting at midnight (top) and going clockwise.
    static func skyGradient(for daylight: Daylight) -> AngularGradient {
        angularGradient { hour in sky(atHour: hour, daylight: daylight) }
    }

    /// Ink gradient around the dial, for tick marks.
    static func inkGradient(for daylight: Daylight) -> AngularGradient {
        angularGradient { hour in nightInk.mixed(with: dayInk, amount: daylight.brightness(atHour: hour)) }
    }

    private static func angularGradient(samples: Int = 96, color: (Double) -> RGBColor) -> AngularGradient {
        var stops: [Gradient.Stop] = []
        for index in 0...samples {
            let location = Double(index) / Double(samples)
            stops.append(Gradient.Stop(color: color(location * 24).color, location: CGFloat(location)))
        }
        return AngularGradient(
            gradient: Gradient(stops: stops),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }
}
