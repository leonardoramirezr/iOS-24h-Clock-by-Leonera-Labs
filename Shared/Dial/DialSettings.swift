import Foundation

/// How the dial is drawn.
struct DialSettings: Codable, Hashable {
    /// Hours of the past shown when the current time is at the top: the quarter of the dial
    /// between the left (9 o'clock) and the top. The other 18 hours, clockwise from the top,
    /// are the future.
    static let pastHoursAtTop: Double = 6

    /// Turns the dial so the current time stays at the top instead of 24. The hand always
    /// points up and the hours move counterclockwise as time goes by.
    var currentTimeAtTop: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentTimeAtTop = (try? container.decode(Bool.self, forKey: .currentTimeAtTop)) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case currentTimeAtTop
    }

    /// The event segments the dial shows at `date`.
    ///
    /// With the current time at the top, the dial covers a rolling window: the last
    /// `pastHoursAtTop` hours and the next `24 - pastHoursAtTop` hours, which can span
    /// two calendar days. Otherwise it shows the calendar day of `date`, from 0 to 24.
    func segments(for events: [ClockEvent], at date: Date, calendar: Calendar = .current) -> [EventSegment] {
        guard currentTimeAtTop else {
            return EventSegment.segments(for: events, on: date, calendar: calendar)
        }
        let start = date.addingTimeInterval(-Self.pastHoursAtTop * 3600)
        return EventSegment.segments(for: events, from: start, calendar: calendar)
    }
}
