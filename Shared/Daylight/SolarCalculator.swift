import Foundation

/// Sunrise and sunset from the NOAA solar equations (accurate to a minute or two).
enum SolarCalculator {
    static func daylight(on date: Date, latitude: Double, longitude: Double, calendar: Calendar = .current) -> Daylight {
        let dayOfYear = Double(calendar.ordinality(of: .day, in: .year, for: date) ?? 1)
        let daysInYear = Double(calendar.range(of: .day, in: .year, for: date)?.count ?? 365)

        // Fractional year (radians) at local noon.
        let gamma: Double = 2 * Double.pi / daysInYear * (dayOfYear - 1)

        var equationOfTime: Double = 0.000075
        equationOfTime += 0.001868 * cos(gamma)
        equationOfTime -= 0.032077 * sin(gamma)
        equationOfTime -= 0.014615 * cos(2 * gamma)
        equationOfTime -= 0.040849 * sin(2 * gamma)
        equationOfTime *= 229.18

        var declination: Double = 0.006918
        declination -= 0.399912 * cos(gamma)
        declination += 0.070257 * sin(gamma)
        declination -= 0.006758 * cos(2 * gamma)
        declination += 0.000907 * sin(2 * gamma)
        declination -= 0.002697 * cos(3 * gamma)
        declination += 0.00148 * sin(3 * gamma)

        // Official zenith of 90.833° accounts for refraction and the solar disc.
        let latitudeRadians = latitude * Double.pi / 180
        let zenith = 90.833 * Double.pi / 180
        let denominator = cos(latitudeRadians) * cos(declination)
        guard abs(denominator) > 1e-9 else {
            return declination * latitude > 0 ? .polarDay : .polarNight
        }
        let cosHourAngle = cos(zenith) / denominator - tan(latitudeRadians) * tan(declination)
        if cosHourAngle > 1 { return .polarNight }
        if cosHourAngle < -1 { return .polarDay }
        let hourAngle = acos(cosHourAngle) * 180 / Double.pi

        let noon = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date
        let offsetMinutes = Double(calendar.timeZone.secondsFromGMT(for: noon)) / 60
        let sunriseMinutes = 720 - 4 * (longitude + hourAngle) - equationOfTime + offsetMinutes
        let sunsetMinutes = 720 - 4 * (longitude - hourAngle) - equationOfTime + offsetMinutes
        return Daylight(sunriseHour: sunriseMinutes / 60, sunsetHour: sunsetMinutes / 60)
    }
}
