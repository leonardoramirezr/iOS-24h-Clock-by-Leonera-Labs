import Foundation

/// The days on which an event starts.
enum EventSchedule: Codable, Hashable {
    /// A single day.
    case once(DayStamp)
    /// Every week on the given weekdays (`Calendar` numbering: 1 = Sunday … 7 = Saturday).
    case weekly(Set<Int>)

    static let allWeekdays: Set<Int> = Set(1...7)
    static let everyDay = EventSchedule.weekly(allWeekdays)

    /// Whether an occurrence starts on the calendar day of `date`.
    func includes(_ date: Date, calendar: Calendar = .current) -> Bool {
        switch self {
        case .once(let day):
            return day == DayStamp(date: date, calendar: calendar)
        case .weekly(let weekdays):
            return weekdays.contains(calendar.component(.weekday, from: date))
        }
    }

    var repeats: Bool {
        switch self {
        case .once:
            return false
        case .weekly:
            return true
        }
    }
}
