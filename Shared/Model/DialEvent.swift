import SwiftUI

/// Something shown on the clock: one of the user's own events, or an occurrence of an event
/// from a connected calendar.
enum DialEvent: Identifiable, Hashable {
    case clock(ClockEvent)
    case calendar(CalendarEvent)

    var id: String {
        switch self {
        case .clock(let event):
            return event.id.uuidString
        case .calendar(let event):
            return "calendar:\(event.id)"
        }
    }

    var title: String {
        switch self {
        case .clock(let event):
            return event.title
        case .calendar(let event):
            return event.displayTitle
        }
    }

    var rgb: RGBColor {
        switch self {
        case .clock(let event):
            return event.color.rgb
        case .calendar(let event):
            return event.color
        }
    }

    var color: Color { rgb.color }

    /// Whether labels drawn on top of this event's color should be dark.
    var prefersDarkText: Bool { rgb.luminance > 0.6 }

    /// Whether the event comes from a connected calendar (and so can't be edited in the app).
    var isFromCalendar: Bool {
        if case .calendar = self {
            return true
        }
        return false
    }
}
