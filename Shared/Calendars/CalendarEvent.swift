import Foundation

/// One occurrence of an event from a connected calendar, read through EventKit.
///
/// Calendar events are read-only in the app: they are drawn on the dial and listed below it,
/// but they are edited in the Calendar app.
struct CalendarEvent: Identifiable, Hashable {
    /// Unique for every occurrence: the EventKit identifier plus the start time.
    let id: String
    /// `EKCalendar.calendarIdentifier` of the calendar the event belongs to.
    let calendarID: String
    let calendarTitle: String
    let title: String
    let start: Date
    let end: Date
    let isAllDay: Bool
    /// The color of the calendar.
    let color: RGBColor
    let location: String?
    let notes: String?

    /// The title, or "Untitled" when the event has none.
    var displayTitle: String {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? NSLocalizedString("Untitled", comment: "Event without a title") : trimmed
    }

    /// Length in minutes, at least 0.
    var durationMinutes: Int {
        max(Int((end.timeIntervalSince(start) / 60).rounded()), 0)
    }

    /// Whether some part of the event falls between `intervalStart` and `intervalEnd`.
    func overlaps(from intervalStart: Date, to intervalEnd: Date) -> Bool {
        start < intervalEnd && end > intervalStart
    }

    /// Ordering for lists: all-day events first, then by start time, then by title.
    static func listOrder(_ lhs: CalendarEvent, _ rhs: CalendarEvent) -> Bool {
        if lhs.isAllDay != rhs.isAllDay {
            return lhs.isAllDay
        }
        if lhs.start != rhs.start {
            return lhs.start < rhs.start
        }
        return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
    }
}
