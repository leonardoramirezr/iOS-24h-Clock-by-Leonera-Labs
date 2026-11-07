import Foundation

/// The part of an event that is visible on the dial of one particular day.
struct EventSegment: Identifiable, Hashable {
    /// One of the user's events or an event of a connected calendar.
    let event: DialEvent
    /// Minutes since midnight (`0..<1440`).
    let startMinute: Int
    /// Visible length in minutes (`1...1440`). It can run past midnight (wrap around the top).
    let durationMinutes: Int

    var id: String { "\(event.id)-\(startMinute)" }

    /// End in minutes since midnight of the same day; can be greater than 1440 when it wraps.
    var endMinute: Int { startMinute + durationMinutes }

    func contains(minute: Int) -> Bool {
        (minute - startMinute).positiveModulo(ClockEvent.minutesPerDay) < durationMinutes
    }

    func overlaps(_ other: EventSegment) -> Bool {
        contains(minute: other.startMinute) || other.contains(minute: startMinute)
    }

    /// Visible segments of `events` and `calendarEvents` on the day of `date`, sorted by start
    /// time (longest first on ties).
    ///
    /// An event that crosses midnight is cut at midnight unless it also started the day before,
    /// so a one-off evening event does not paint the early hours of its own day. Calendar events
    /// are cut at both midnights of the day.
    static func segments(
        for events: [ClockEvent],
        calendarEvents: [CalendarEvent] = [],
        on date: Date,
        calendar: Calendar = .current
    ) -> [EventSegment] {
        let previousDay = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        var result: [EventSegment] = []
        for event in events {
            let startsToday = event.starts(on: date, calendar: calendar)
            let carriesOver = event.crossesMidnight && event.starts(on: previousDay, calendar: calendar)
            if startsToday && carriesOver {
                result.append(EventSegment(event: .clock(event), startMinute: event.startMinute, durationMinutes: event.durationMinutes))
            } else if startsToday {
                let visible = min(event.durationMinutes, ClockEvent.minutesPerDay - event.startMinute)
                result.append(EventSegment(event: .clock(event), startMinute: event.startMinute, durationMinutes: visible))
            } else if carriesOver {
                let tail = event.startMinute + event.durationMinutes - ClockEvent.minutesPerDay
                result.append(EventSegment(event: .clock(event), startMinute: 0, durationMinutes: tail))
            }
        }
        if !calendarEvents.isEmpty {
            let dayStart = calendar.startOfDay(for: date)
            let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart)
                ?? dayStart.addingTimeInterval(TimeInterval(ClockEvent.minutesPerDay * 60))
            result += calendarSegments(calendarEvents, from: dayStart, to: dayEnd, calendar: calendar)
        }
        return sortedForDial(result)
    }

    /// Visible segments of `events` and `calendarEvents` in the 24 hours that begin at `start`,
    /// placed on the dial by their time of day. A segment can wrap past midnight, and the
    /// occurrences of the day before, the day of `start` and the next day are all taken into
    /// account.
    ///
    /// Occurrences are cut at both ends of the window, so the same repeating event can show
    /// up twice: the end of one occurrence where the window begins and the start of the next
    /// one where it ends.
    static func segments(
        for events: [ClockEvent],
        calendarEvents: [CalendarEvent] = [],
        from start: Date,
        calendar: Calendar = .current
    ) -> [EventSegment] {
        let windowStart = Date(timeIntervalSinceReferenceDate: (start.timeIntervalSinceReferenceDate / 60).rounded(.down) * 60)
        let windowEnd = windowStart.addingTimeInterval(TimeInterval(ClockEvent.minutesPerDay * 60))
        let firstDay = calendar.startOfDay(for: windowStart)
        var result: [EventSegment] = []
        for dayOffset in -1...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: firstDay) else { continue }
            for event in events where event.starts(on: day, calendar: calendar) {
                let occurrenceStart = day.atMinuteOfDay(event.startMinute, calendar: calendar)
                let occurrenceEnd = occurrenceStart.addingTimeInterval(TimeInterval(event.durationMinutes * 60))
                let visibleStart = max(occurrenceStart, windowStart)
                let visibleEnd = min(occurrenceEnd, windowEnd)
                let minutes = Int((visibleEnd.timeIntervalSince(visibleStart) / 60).rounded())
                guard minutes > 0 else { continue }
                result.append(EventSegment(
                    event: .clock(event),
                    startMinute: visibleStart.minuteOfDay(calendar: calendar),
                    durationMinutes: min(minutes, ClockEvent.minutesPerDay)
                ))
            }
        }
        result += calendarSegments(calendarEvents, from: windowStart, to: windowEnd, calendar: calendar)
        return sortedForDial(result)
    }

    /// The parts of the timed `calendarEvents` between `windowStart` and `windowEnd` (about a
    /// day apart), placed on the dial by their time of day.
    ///
    /// All-day events are left out: they would cover the whole dial and push every other event
    /// into a narrower lane. The app lists them below the clock instead.
    private static func calendarSegments(
        _ calendarEvents: [CalendarEvent],
        from windowStart: Date,
        to windowEnd: Date,
        calendar: Calendar
    ) -> [EventSegment] {
        calendarEvents.compactMap { event -> EventSegment? in
            guard !event.isAllDay else { return nil }
            let visibleStart = max(event.start, windowStart)
            let visibleEnd = min(event.end, windowEnd)
            let minutes = Int((visibleEnd.timeIntervalSince(visibleStart) / 60).rounded())
            guard minutes > 0 else { return nil }
            return EventSegment(
                event: .calendar(event),
                startMinute: visibleStart.minuteOfDay(calendar: calendar),
                durationMinutes: min(minutes, ClockEvent.minutesPerDay)
            )
        }
    }

    /// Sorted by start time, longest first on ties.
    private static func sortedForDial(_ segments: [EventSegment]) -> [EventSegment] {
        segments.sorted { lhs, rhs in
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
