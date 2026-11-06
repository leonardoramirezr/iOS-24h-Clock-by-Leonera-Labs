import Foundation

/// How the app decides which hours of the day are daytime.
struct DaylightSettings: Codable, Hashable {
    enum Source: String, Codable, CaseIterable, Identifiable {
        /// Fixed sunrise and sunset times chosen by the user.
        case manual
        /// Sunrise and sunset calculated for the last known location.
        case location

        var id: String { rawValue }
    }

    static let defaultSunriseMinute = 6 * 60
    static let defaultSunsetMinute = 18 * 60

    var source: Source = .manual
    /// Manual sunrise in minutes since midnight.
    var sunriseMinute: Int = DaylightSettings.defaultSunriseMinute
    /// Manual sunset in minutes since midnight.
    var sunsetMinute: Int = DaylightSettings.defaultSunsetMinute
    /// Last known latitude, rounded to about 10 km for privacy.
    var latitude: Double?
    /// Last known longitude, rounded to about 10 km for privacy.
    var longitude: Double?

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        source = (try? container.decode(Source.self, forKey: .source)) ?? .manual
        sunriseMinute = (try? container.decode(Int.self, forKey: .sunriseMinute)) ?? DaylightSettings.defaultSunriseMinute
        sunsetMinute = (try? container.decode(Int.self, forKey: .sunsetMinute)) ?? DaylightSettings.defaultSunsetMinute
        latitude = try? container.decodeIfPresent(Double.self, forKey: .latitude)
        longitude = try? container.decodeIfPresent(Double.self, forKey: .longitude)
    }

    private enum CodingKeys: String, CodingKey {
        case source
        case sunriseMinute
        case sunsetMinute
        case latitude
        case longitude
    }

    var hasLocation: Bool {
        latitude != nil && longitude != nil
    }

    /// Stores a coordinate rounded to one decimal place.
    mutating func setLocation(latitude: Double, longitude: Double) {
        self.latitude = (latitude * 10).rounded() / 10
        self.longitude = (longitude * 10).rounded() / 10
    }

    func daylight(on date: Date, calendar: Calendar = .current) -> Daylight {
        if source == .location, let latitude = latitude, let longitude = longitude {
            return SolarCalculator.daylight(on: date, latitude: latitude, longitude: longitude, calendar: calendar)
        }
        return Daylight(sunriseHour: Double(sunriseMinute) / 60, sunsetHour: Double(sunsetMinute) / 60)
    }
}
