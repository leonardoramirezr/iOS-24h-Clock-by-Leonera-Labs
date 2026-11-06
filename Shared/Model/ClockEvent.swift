import Foundation

/// A block of time that is drawn as a pie slice on the 24-hour dial.
struct ClockEvent: Identifiable, Codable, Hashable {
    static let minutesPerDay = TimeText.minutesPerDay

    var id: UUID
    var title: String
    /// Start time in minutes since midnight (`0..<1440`).
    var startMinute: Int
    /// End time in minutes since midnight (`0..<1440`).
    /// A value lower than `startMinute` means that the event ends the next day.
    var endMinute: Int
    var color: EventColor
    var schedule: EventSchedule

    init(
        id: UUID = UUID(),
        title: String,
        startMinute: Int,
        endMinute: Int,
        color: EventColor,
        schedule: EventSchedule
    ) {
        self.id = id
        self.title = title
        self.startMinute = startMinute.positiveModulo(Self.minutesPerDay)
        self.endMinute = endMinute.positiveModulo(Self.minutesPerDay)
        self.color = color
        self.schedule = schedule
    }

    /// Length in minutes (`1...1440`). Equal start and end times mean a full day.
    var durationMinutes: Int {
        let duration = (endMinute - startMinute).positiveModulo(Self.minutesPerDay)
        return duration == 0 ? Self.minutesPerDay : duration
    }

    /// Whether the event continues after midnight of the day it starts.
    var crossesMidnight: Bool {
        startMinute + durationMinutes > Self.minutesPerDay
    }

    /// Whether an occurrence of the event starts on the day of `date`.
    func starts(on date: Date, calendar: Calendar = .current) -> Bool {
        schedule.includes(date, calendar: calendar)
    }

    /// A new, untitled one-hour event that starts at the next full hour.
    static func draft(at date: Date, color: EventColor, calendar: Calendar = .current) -> ClockEvent {
        let nextHour = (date.minuteOfDay(calendar: calendar) / 60 + 1) * 60
        var day = date
        if nextHour >= minutesPerDay, let tomorrow = calendar.date(byAdding: .day, value: 1, to: date) {
            day = tomorrow
        }
        return ClockEvent(
            title: "",
            startMinute: nextHour,
            endMinute: nextHour + 60,
            color: color,
            schedule: .once(DayStamp(date: day, calendar: calendar))
        )
    }
}
