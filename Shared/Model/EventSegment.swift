import Foundation

/// The part of an event that is visible on the dial of one particular day.
struct EventSegment: Identifiable, Hashable {
    let event: ClockEvent
    /// Minutes since midnight (`0..<1440`).
    let startMinute: Int
    /// Visible length in minutes (`1...1440`). It can run past midnight (wrap around the top).
    let durationMinutes: Int

    var id: String { "\(event.id.uuidString)-\(startMinute)" }

    /// End in minutes since midnight of the same day; can be greater than 1440 when it wraps.
    var endMinute: Int { startMinute + durationMinutes }

    func contains(minute: Int) -> Bool {
        (minute - startMinute).positiveModulo(ClockEvent.minutesPerDay) < durationMinutes
    }

    func overlaps(_ other: EventSegment) -> Bool {
        contains(minute: other.startMinute) || other.contains(minute: startMinute)
    }

    /// Visible segments of `events` on the day of `date`, sorted by start time (longest first on ties).
    ///
    /// An event that crosses midnight is cut at midnight unless it also started the day before,
    /// so a one-off evening event does not paint the early hours of its own day.
    static func segments(for events: [ClockEvent], on date: Date, calendar: Calendar = .current) -> [EventSegment] {
        let previousDay = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        var result: [EventSegment] = []
        for event in events {
            let startsToday = event.starts(on: date, calendar: calendar)
            let carriesOver = event.crossesMidnight && event.starts(on: previousDay, calendar: calendar)
            if startsToday && carriesOver {
                result.append(EventSegment(event: event, startMinute: event.startMinute, durationMinutes: event.durationMinutes))
            } else if startsToday {
                let visible = min(event.durationMinutes, ClockEvent.minutesPerDay - event.startMinute)
                result.append(EventSegment(event: event, startMinute: event.startMinute, durationMinutes: visible))
            } else if carriesOver {
                let tail = event.startMinute + event.durationMinutes - ClockEvent.minutesPerDay
                result.append(EventSegment(event: event, startMinute: 0, durationMinutes: tail))
            }
        }
        return result.sorted { lhs, rhs in
            if lhs.startMinute != rhs.startMinute {
                return lhs.startMinute < rhs.startMinute
            }
            return lhs.durationMinutes > rhs.durationMinutes
        }
    }
}

/// What is happening now and what comes next, for a list of segments of one day.
struct DayAgenda {
    let current: EventSegment?
    let next: EventSegment?

    init(segments: [EventSegment], date: Date, calendar: Calendar = .current) {
        let minute = date.minuteOfDay(calendar: calendar)
        let active = segments.filter { $0.contains(minute: minute) }
        // The most recently started event is the most specific one.
        current = active.max { lhs, rhs in
            (minute - lhs.startMinute).positiveModulo(ClockEvent.minutesPerDay)
                > (minute - rhs.startMinute).positiveModulo(ClockEvent.minutesPerDay)
        }
        next = segments
            .filter { $0.startMinute > minute }
            .min { $0.startMinute < $1.startMinute }
    }
}
