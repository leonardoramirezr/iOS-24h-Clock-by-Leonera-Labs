import Foundation

enum WeekdayOrder {
    /// Weekday numbers (1 = Sunday … 7 = Saturday) starting at the calendar's first weekday.
    static func ordered(calendar: Calendar = .current) -> [Int] {
        (0..<7).map { offset in (calendar.firstWeekday - 1 + offset) % 7 + 1 }
    }
}

extension EventSchedule {
    /// A short, localized description such as "Every day", "Weekdays" or "Mon, Wed".
    var localizedDescription: String {
        switch self {
        case .once(let day):
            return day.date().formatted(date: .abbreviated, time: .omitted)
        case .weekly(let weekdays):
            if weekdays == EventSchedule.allWeekdays {
                return NSLocalizedString("Every day", comment: "Event repeats every day")
            }
            if weekdays == [2, 3, 4, 5, 6] {
                return NSLocalizedString("Weekdays", comment: "Event repeats Monday to Friday")
            }
            if weekdays == [1, 7] {
                return NSLocalizedString("Weekends", comment: "Event repeats on Saturday and Sunday")
            }
            let calendar = Calendar.current
            let symbols = calendar.shortStandaloneWeekdaySymbols
            return WeekdayOrder.ordered(calendar: calendar)
                .filter { weekdays.contains($0) }
                .map { symbols[$0 - 1] }
                .joined(separator: ", ")
        }
    }
}

extension ClockEvent {
    /// Ordering for event lists: repeating events by time, then one-off events by date and time.
    static func listOrder(_ lhs: ClockEvent, _ rhs: ClockEvent) -> Bool {
        switch (lhs.schedule, rhs.schedule) {
        case let (.once(first), .once(second)) where first != second:
            return first < second
        case (.weekly, .once):
            return true
        case (.once, .weekly):
            return false
        default:
            return lhs.startMinute < rhs.startMinute
        }
    }

    var displayTitle: String {
        title.isEmpty ? NSLocalizedString("Untitled", comment: "Event without a title") : title
    }
}
