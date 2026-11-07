import Foundation

/// Which of the iPhone's calendars are connected to the clock.
struct CalendarSettings: Codable, Hashable {
    /// `EKCalendar.calendarIdentifier` of every connected calendar.
    var calendarIDs: Set<String> = []

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        calendarIDs = (try? container.decode(Set<String>.self, forKey: .calendarIDs)) ?? []
    }

    private enum CodingKeys: String, CodingKey {
        case calendarIDs
    }

    /// Whether at least one calendar is connected.
    var isConnected: Bool {
        !calendarIDs.isEmpty
    }
}
