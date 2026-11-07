import Foundation

/// Everything the app shares with the widget.
struct AppSnapshot: Codable, Hashable {
    var events: [ClockEvent]
    var daylight: DaylightSettings
    var dial: DialSettings
    var calendars: CalendarSettings

    init(
        events: [ClockEvent] = [],
        daylight: DaylightSettings = DaylightSettings(),
        dial: DialSettings = DialSettings(),
        calendars: CalendarSettings = CalendarSettings()
    ) {
        self.events = events
        self.daylight = daylight
        self.dial = dial
        self.calendars = calendars
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        events = (try? container.decode([ClockEvent].self, forKey: .events)) ?? []
        daylight = (try? container.decode(DaylightSettings.self, forKey: .daylight)) ?? DaylightSettings()
        dial = (try? container.decode(DialSettings.self, forKey: .dial)) ?? DialSettings()
        calendars = (try? container.decode(CalendarSettings.self, forKey: .calendars)) ?? CalendarSettings()
    }

    private enum CodingKeys: String, CodingKey {
        case events
        case daylight
        case dial
        case calendars
    }

    static let empty = AppSnapshot()

    /// Example content shown in the widget gallery.
    static var sample: AppSnapshot {
        AppSnapshot(events: [
            ClockEvent(
                title: NSLocalizedString("Sleep", comment: "Sample event title"),
                startMinute: 23 * 60,
                endMinute: 7 * 60,
                color: .indigo,
                schedule: .everyDay
            ),
            ClockEvent(
                title: NSLocalizedString("Work", comment: "Sample event title"),
                startMinute: 9 * 60,
                endMinute: 14 * 60,
                color: .blue,
                schedule: .everyDay
            ),
            ClockEvent(
                title: NSLocalizedString("Workout", comment: "Sample event title"),
                startMinute: 18 * 60,
                endMinute: 19 * 60 + 30,
                color: .orange,
                schedule: .everyDay
            ),
        ])
    }
}

extension JSONEncoder {
    static var snapshot: JSONEncoder {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        return encoder
    }
}
