import SwiftUI

/// An event from a connected calendar in the list below the clock.
struct CalendarEventRow: View {
    let event: CalendarEvent

    var body: some View {
        HStack(spacing: 12) {
            // A rounded square, so calendar events stand apart from the app's own (round) ones.
            RoundedRectangle(cornerRadius: 3.5, style: .continuous)
                .fill(event.color.color)
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: event.displayTitle)
                    .font(.body.weight(.medium))
                Text(verbatim: event.timeRangeText)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Label {
                    Text(verbatim: event.calendarTitle)
                } icon: {
                    Image(systemName: "calendar")
                }
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }
}

extension CalendarEvent {
    /// The last moment of the event that belongs to it. EventKit ends all-day events on the
    /// last second of their last day or at midnight after it, so one second is taken off.
    var lastMoment: Date {
        isAllDay ? max(start, end.addingTimeInterval(-1)) : end
    }

    /// Whether the event covers more than one calendar day.
    var spansSeveralDays: Bool {
        !Calendar.current.isDate(start, inSameDayAs: lastMoment)
    }

    /// "09:00 – 10:30 · 1h 30m", with the dates for events of a day or longer, or "All day".
    var timeRangeText: String {
        if isAllDay {
            let allDay = NSLocalizedString("All day", comment: "An event that lasts the whole day")
            guard spansSeveralDays else { return allDay }
            return "\(allDay) · \(Self.shortDate(start)) – \(Self.shortDate(lastMoment))"
        }
        let startTime = TimeText.string(date: start)
        let endTime = TimeText.string(date: end)
        let duration = TimeText.duration(minutes: durationMinutes, includesDays: true)
        // Shorter events read like the app's own events, even when they cross midnight.
        if durationMinutes < TimeText.minutesPerDay {
            return "\(startTime) – \(endTime) · \(duration)"
        }
        return "\(Self.shortDate(start)) \(startTime) – \(Self.shortDate(end)) \(endTime) · \(duration)"
    }

    /// The day and the abbreviated month, such as "Nov 8".
    static func shortDate(_ date: Date) -> String {
        date.formatted(.dateTime.day().month(.abbreviated))
    }
}
