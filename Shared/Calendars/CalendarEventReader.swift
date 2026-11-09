import CoreGraphics
import EventKit
import Foundation

/// Reads the events of the connected calendars through EventKit, for the app and the widget.
///
/// Only the app asks for access (see `CalendarService`). The widget extension uses the access
/// that the user gave to the app, so it reads the calendars itself and stays up to date
/// without the app.
enum CalendarEventReader {
    /// Whether events can be read: the user gave the app full access to calendars.
    static var hasFullAccess: Bool {
        EKEventStore.authorizationStatus(for: .event) == .fullAccess
    }

    /// The occurrences of the events of `calendarIDs` that overlap `start..<end`, in list order.
    static func events(
        from start: Date,
        to end: Date,
        calendarIDs: Set<String>,
        in store: EKEventStore = EKEventStore()
    ) -> [CalendarEvent] {
        guard hasFullAccess, !calendarIDs.isEmpty, end > start else { return [] }
        let calendars = store.calendars(for: .event).filter { calendarIDs.contains($0.calendarIdentifier) }
        // An empty list would mean "every calendar" to EventKit.
        guard !calendars.isEmpty else { return [] }
        let predicate = store.predicateForEvents(withStart: start, end: end, calendars: calendars)
        return store.events(matching: predicate)
            .compactMap { calendarEvent(from: $0) }
            .sorted(by: CalendarEvent.listOrder)
    }

    /// The color of a calendar, in sRGB.
    static func color(of calendar: EKCalendar) -> RGBColor {
        let cgColor: CGColor? = calendar.cgColor
        return cgColor.flatMap { RGBColor(cgColor: $0) } ?? EventColor.gray.rgb
    }

    private static func calendarEvent(from event: EKEvent) -> CalendarEvent? {
        // Typed as optionals because EventKit doesn't promise these values for every event.
        let eventCalendar: EKCalendar? = event.calendar
        let eventStart: Date? = event.startDate
        let eventEnd: Date? = event.endDate
        guard let calendar = eventCalendar, let start = eventStart, let end = eventEnd else { return nil }
        let identifier: String? = event.eventIdentifier
        let title: String? = event.title
        return CalendarEvent(
            id: "\(identifier ?? event.calendarItemIdentifier)@\(Int(start.timeIntervalSinceReferenceDate))",
            calendarID: calendar.calendarIdentifier,
            calendarTitle: calendar.title,
            title: title ?? "",
            start: start,
            end: max(end, start),
            isAllDay: event.isAllDay,
            color: color(of: calendar),
            location: event.location,
            notes: event.notes
        )
    }
}
