import EventKit
import Foundation
import WidgetKit

/// A calendar of the iPhone that can be connected to the clock.
struct CalendarInfo: Identifiable, Hashable {
    /// `EKCalendar.calendarIdentifier`.
    let id: String
    let title: String
    let color: RGBColor
    /// The account the calendar belongs to, such as iCloud or Gmail.
    let sourceID: String
    let sourceTitle: String
}

/// Connects the app to the iPhone's calendars through EventKit: it asks for access, lists the
/// calendars, and keeps the events of the connected ones loaded for the dial and the lists.
///
/// Which calendars are connected is stored in `CalendarSettings` (part of the snapshot shared
/// with the widget), and `show(calendarIDs:)` tells this service about it.
final class CalendarService: ObservableObject {
    enum Access: Equatable {
        case notDetermined
        case granted
        /// Denied, restricted, or write-only access. None of them can read events.
        case denied
    }

    @Published private(set) var access: Access
    /// Calendars that can hold events, grouped by account and sorted by title.
    @Published private(set) var calendars: [CalendarInfo] = []
    /// Events of the connected calendars, from yesterday to `daysAhead` days after today.
    @Published private(set) var events: [CalendarEvent] = []

    private let eventStore = EKEventStore()
    private var calendarIDs: Set<String> = []
    /// Days after today whose events are loaded. It grows when the user browses further ahead.
    private var daysAhead = 7
    private var changeObserver: NSObjectProtocol?
    private var pendingRefresh: DispatchWorkItem?

    init() {
        access = Self.currentAccess()
        reloadCalendars()
        // Posted when the calendars change, in the app or on another device.
        changeObserver = NotificationCenter.default.addObserver(
            forName: .EKEventStoreChanged,
            object: eventStore,
            queue: .main
        ) { [weak self] _ in
            self?.scheduleRefresh()
        }
    }

    deinit {
        if let observer = changeObserver {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    /// Asks for full access to the calendars. `completion` runs on the main queue once the
    /// calendars are loaded, with whether access was granted.
    func requestAccess(completion: @escaping (Bool) -> Void) {
        eventStore.requestFullAccessToEvents { [weak self] granted, _ in
            DispatchQueue.main.async {
                guard let self = self else { return }
                if granted {
                    // Calendars loaded before access was granted can be stale.
                    self.eventStore.reset()
                }
                self.refresh()
                completion(granted)
            }
        }
    }

    /// Shows the events of these calendars.
    func show(calendarIDs ids: Set<String>) {
        guard ids != calendarIDs else { return }
        calendarIDs = ids
        reloadEvents()
    }

    /// Makes sure the events of the day `dayOffset` days after today are loaded.
    func include(dayOffset: Int) {
        guard dayOffset > daysAhead else { return }
        daysAhead = dayOffset + 7
        reloadEvents()
    }

    /// Reads the access status, the calendars and their events again, for example when the
    /// app becomes active (the user may have changed the access in Settings).
    func refresh() {
        access = Self.currentAccess()
        reloadCalendars()
        reloadEvents()
    }

    /// Calendars change in bursts while they sync, so the changes are handled together.
    private func scheduleRefresh() {
        pendingRefresh?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.refresh()
            // The widget reads the calendars itself, but it only finds out about changes
            // when its timeline reloads.
            WidgetCenter.shared.reloadAllTimelines()
        }
        pendingRefresh = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: work)
    }

    private func reloadCalendars() {
        guard access == .granted else {
            calendars = []
            return
        }
        calendars = eventStore.calendars(for: .event)
            .map { calendar -> CalendarInfo in
                let source: EKSource? = calendar.source
                return CalendarInfo(
                    id: calendar.calendarIdentifier,
                    title: calendar.title,
                    color: CalendarEventReader.color(of: calendar),
                    sourceID: source?.sourceIdentifier ?? "",
                    sourceTitle: source?.title ?? ""
                )
            }
            .sorted { lhs, rhs in
                if lhs.sourceTitle != rhs.sourceTitle {
                    return lhs.sourceTitle.localizedStandardCompare(rhs.sourceTitle) == .orderedAscending
                }
                if lhs.sourceID != rhs.sourceID {
                    return lhs.sourceID < rhs.sourceID
                }
                return lhs.title.localizedStandardCompare(rhs.title) == .orderedAscending
            }
    }

    private func reloadEvents() {
        guard access == .granted, !calendarIDs.isEmpty else {
            events = []
            return
        }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        guard let start = calendar.date(byAdding: .day, value: -1, to: today),
              let end = calendar.date(byAdding: .day, value: daysAhead + 1, to: today) else { return }
        events = CalendarEventReader.events(from: start, to: end, calendarIDs: calendarIDs, in: eventStore)
    }

    private static func currentAccess() -> Access {
        switch EKEventStore.authorizationStatus(for: .event) {
        case .notDetermined:
            return .notDetermined
        case .fullAccess:
            return .granted
        default:
            return .denied
        }
    }
}
