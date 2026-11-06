import Foundation

/// Time formatting helpers. The app always shows a 24-hour clock.
enum TimeText {
    static let minutesPerDay = 24 * 60

    /// `HH:mm` for a number of minutes since midnight.
    static func string(minuteOfDay: Int) -> String {
        let minute = minuteOfDay.positiveModulo(minutesPerDay)
        return String(format: "%02ld:%02ld", minute / 60, minute % 60)
    }

    /// `HH:mm` for a fractional hour of the day.
    static func string(hour: Double) -> String {
        string(minuteOfDay: Int((hour * 60).rounded()))
    }

    /// `HH:mm` for the time of `date`.
    static func string(date: Date, calendar: Calendar = .current) -> String {
        string(minuteOfDay: date.minuteOfDay(calendar: calendar))
    }

    /// A localized, abbreviated duration such as "1h 30m".
    static func duration(minutes: Int) -> String {
        let formatter = DateComponentsFormatter()
        formatter.allowedUnits = [.hour, .minute]
        formatter.unitsStyle = .abbreviated
        formatter.zeroFormattingBehavior = .dropAll
        return formatter.string(from: TimeInterval(minutes * 60)) ?? "\(minutes) min"
    }
}

extension Date {
    /// Minutes since midnight in `calendar`'s time zone.
    func minuteOfDay(calendar: Calendar = .current) -> Int {
        let components = calendar.dateComponents([.hour, .minute], from: self)
        return (components.hour ?? 0) * 60 + (components.minute ?? 0)
    }

    /// Fractional hour of the day (`0..<24`), including seconds.
    func hourOfDay(calendar: Calendar = .current) -> Double {
        let components = calendar.dateComponents([.hour, .minute, .second], from: self)
        let hours = Double(components.hour ?? 0)
        let minutes = Double(components.minute ?? 0) / 60
        let seconds = Double(components.second ?? 0) / 3600
        return hours + minutes + seconds
    }

    /// The same calendar day at the given minute of the day.
    func atMinuteOfDay(_ minute: Int, calendar: Calendar = .current) -> Date {
        let value = minute.positiveModulo(TimeText.minutesPerDay)
        return calendar.date(bySettingHour: value / 60, minute: value % 60, second: 0, of: self) ?? self
    }
}

extension Locale {
    /// The current locale with a 0–23 hour cycle, for system time styles.
    static var twentyFourHour: Locale {
        var components = Locale.Components(locale: .current)
        components.hourCycle = .zeroToTwentyThree
        return Locale(components: components)
    }
}
