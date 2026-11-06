import Foundation

/// A calendar day that does not shift when the time zone changes.
struct DayStamp: Codable, Hashable, Comparable {
    var year: Int
    var month: Int
    var day: Int

    init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }

    init(date: Date, calendar: Calendar = .current) {
        let components = calendar.dateComponents([.year, .month, .day], from: date)
        self.init(year: components.year ?? 2000, month: components.month ?? 1, day: components.day ?? 1)
    }

    /// Noon of this day, which is safe from daylight saving time transitions.
    func date(calendar: Calendar = .current) -> Date {
        calendar.date(from: DateComponents(year: year, month: month, day: day, hour: 12)) ?? Date()
    }

    static func < (lhs: DayStamp, rhs: DayStamp) -> Bool {
        if lhs.year != rhs.year { return lhs.year < rhs.year }
        if lhs.month != rhs.month { return lhs.month < rhs.month }
        return lhs.day < rhs.day
    }
}
