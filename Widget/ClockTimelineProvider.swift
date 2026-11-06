import Foundation
import WidgetKit

struct ClockEntry: TimelineEntry {
    let date: Date
    let snapshot: AppSnapshot
}

/// Provides an entry every five minutes (the hand of a 24-hour dial moves 1.25° in that time).
struct ClockTimelineProvider: TimelineProvider {
    private let stepMinutes = 5
    private let entryCount = 48

    func placeholder(in context: Context) -> ClockEntry {
        ClockEntry(date: Date(), snapshot: .sample)
    }

    func getSnapshot(in context: Context, completion: @escaping (ClockEntry) -> Void) {
        let stored = SharedSnapshotStore.load()
        let hasEvents = !(stored?.events.isEmpty ?? true)
        // The widget gallery shows sample events until the user has created some.
        let snapshot = context.isPreview && !hasEvents ? AppSnapshot.sample : (stored ?? .empty)
        completion(ClockEntry(date: Date(), snapshot: snapshot))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<ClockEntry>) -> Void) {
        let snapshot = SharedSnapshotStore.load() ?? .empty
        let now = Date()
        let step = TimeInterval(stepMinutes * 60)
        let firstBoundary = (now.timeIntervalSinceReferenceDate / step).rounded(.up) * step
        var entries = [ClockEntry(date: now, snapshot: snapshot)]
        for index in 0..<entryCount {
            let date = Date(timeIntervalSinceReferenceDate: firstBoundary + Double(index) * step)
            if date > now {
                entries.append(ClockEntry(date: date, snapshot: snapshot))
            }
        }
        completion(Timeline(entries: entries, policy: .atEnd))
    }
}
