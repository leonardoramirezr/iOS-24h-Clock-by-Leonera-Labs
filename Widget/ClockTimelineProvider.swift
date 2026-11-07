import Foundation
import WidgetKit

struct ClockEntry: TimelineEntry {
    let date: Date
    let snapshot: AppSnapshot
    /// Events of the connected calendars around `date`.
    var calendarEvents: [CalendarEvent] = []
}

/// Provides an entry every five minutes (the hand of a 24-hour dial moves 1.25° in that time).
///
/// The widget reads the connected calendars itself, with the access the user gave to the app.
/// It can't be told when a calendar changes while the app is closed, so with calendars
/// connected it asks for a new timeline every hour.
struct ClockTimelineProvider: TimelineProvider {
    private let stepMinutes = 5
    private let entryCount = 48
    private let calendarRefreshInterval: TimeInterval = 3600

    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        let stored = SharedSnapshotStore.load()
        let hasEvents = !(stored?.events.isEmpty ?? true)
        // The widget gallery shows sample events until the user has created some.
        let snapshot = context.isPreview && !hasEvents ? AppSnapshot.sample : (stored ?? .empty)
        let now = Date()
        completion(ClockEntry(date: now, snapshot: snapshot, calendarEvents: loadCalendarEvents(for: snapshot, around: now)))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let snapshot = SharedSnapshotStore.load() ?? .empty
        let now = Date()
        let calendarEvents = loadCalendarEvents(for: snapshot, around: now)
        let step = TimeInterval(stepMinutes * 60)
        let firstBoundary = (now.timeIntervalSinceReferenceDate / step).rounded(.up) * step
        var entries = [ClockEntry(date: now, snapshot: snapshot, calendarEvents: calendarEvents)]
        for index in 0..<entryCount {
            let date = Date(timeIntervalSinceReferenceDate: firstBoundary + Double(index) * step)
            if date > now {
                entries.append(ClockEntry(date: date, snapshot: snapshot, calendarEvents: calendarEvents))
            }
        }
        let policy: TimelineReloadPolicy = snapshot.calendars.isConnected
            ? .after(now.addingTimeInterval(calendarRefreshInterval))
            : .atEnd
        completion(Timeline(entries: entries, policy: policy))
    }

    /// Events of the connected calendars from a day before `date` to two days after it. That
    /// covers every entry of a timeline, whether the dial shows the calendar day or the hours
    /// around the current time.
    private func loadCalendarEvents(for snapshot: AppSnapshot, around date: Date) -> [CalendarEvent] {
        guard snapshot.calendars.isConnected else { return [] }
        let day: TimeInterval = 24 * 3600
        return CalendarEventReader.events(
            from: date.addingTimeInterval(-day),
            to: date.addingTimeInterval(2 * day),
            calendarIDs: snapshot.calendars.calendarIDs
        )
    }
}
