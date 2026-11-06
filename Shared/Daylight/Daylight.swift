import Foundation

/// Daytime and nighttime of one day, used to paint the dial.
enum Daylight: Hashable {
    /// Hours (`0..<24`) of sunrise and sunset in local time.
    case normal(sunriseHour: Double, sunsetHour: Double)
    /// The sun does not set.
    case polarDay
    /// The sun does not rise.
    case polarNight

    /// Width in hours of the blended band on each side of sunrise and sunset.
    static let twilightHours = 0.75

    init(sunriseHour: Double, sunsetHour: Double) {
        let sunrise = sunriseHour.positiveModulo(24)
        let sunset = sunsetHour.positiveModulo(24)
        if abs(sunrise - sunset) < 1.0 / 60 {
            self = .polarNight
        } else {
            self = .normal(sunriseHour: sunrise, sunsetHour: sunset)
        }
    }

    var sunriseHour: Double? {
        if case let .normal(sunrise, _) = self { return sunrise }
        return nil
    }

    var sunsetHour: Double? {
        if case let .normal(_, sunset) = self { return sunset }
        return nil
    }

    /// Hours of daylight.
    var dayLength: Double {
        switch self {
        case let .normal(sunrise, sunset):
            return (sunset - sunrise).positiveModulo(24)
        case .polarDay:
            return 24
        case .polarNight:
            return 0
        }
    }

    /// Middle of the daytime (solar noon).
    var middayHour: Double {
        if case let .normal(sunrise, _) = self {
            return (sunrise + dayLength / 2).positiveModulo(24)
        }
        return 12
    }

    /// Middle of the night.
    var midnightHour: Double {
        (middayHour + 12).positiveModulo(24)
    }

    func isDaytime(atHour hour: Double) -> Bool {
        signedDepth(atHour: hour) > 0
    }

    /// 0 at night and 1 during the day, with a smooth blend around sunrise and sunset.
    func brightness(atHour hour: Double) -> Double {
        let width = Daylight.twilightHours
        return Interpolation.smoothstep(-width, width, signedDepth(atHour: hour))
    }

    /// 1 exactly at sunrise or sunset, fading to 0 one twilight width away from it.
    func twilightIntensity(atHour hour: Double) -> Double {
        let distance = abs(signedDepth(atHour: hour))
        return max(0, 1 - distance / Daylight.twilightHours)
    }

    /// Distance in hours to the closest sunrise or sunset: positive by day, negative at night.
    private func signedDepth(atHour hour: Double) -> Double {
        switch self {
        case .polarDay:
            return 24
        case .polarNight:
            return -24
        case let .normal(sunrise, _):
            let length = dayLength
            let position = (hour - sunrise).positiveModulo(24)
            if position < length {
                return min(position, length - position)
            }
            return -min(position - length, 24 - position)
        }
    }
}
