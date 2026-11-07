import SwiftUI

/// The main screen: the 24-hour clock with today's events, followed by every other event.
///
/// Unless the current time is at the top, swiping the clock from right to left shows the
/// next days (and from left to right goes back, down to today).
struct ContentView: View {
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var locationService: LocationService
    @Environment(\.scenePhase) private var scenePhase

    @State private var editorRequest: EditorRequest?
    @State private var isShowingSettings = false
    /// Days after today shown on the dial; 0 is today.
    @State private var dayOffset = 0
    /// Horizontal offset of the clock while it is being swiped.
    @State private var swipeOffset: CGFloat = 0

    /// Swipes shorter than this go back to the same day.
    private let swipeThreshold: CGFloat = 60

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                content(now: context.date)
            }
            .navigationTitle(Text("24H Clock"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                if dayOffset > 0 {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Today") {
                            showDay(0)
                        }
                    }
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let draft = ClockEvent.draft(at: day(at: Date()), color: store.suggestedColor())
                        editorRequest = EditorRequest(event: draft, isNew: true)
                    } label: {
                        Label("Add Event", systemImage: "plus")
                    }
                }
            }
        }
        .sheet(item: $editorRequest) { request in
            EventEditorView(event: request.event, isNew: request.isNew)
                .environmentObject(store)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
                .environmentObject(store)
                .environmentObject(locationService)
        }
        .onChange(of: scenePhase) { _, phase in
            if phase == .active {
                refreshLocation()
            }
        }
        .onChange(of: store.dialSettings.currentTimeAtTop) { _, isAtTop in
            if isAtTop {
                dayOffset = 0
                swipeOffset = 0
            }
        }
    }

    /// Whether the user can move to other days. The dial with the current time at the top
    /// always shows the hours around now.
    private var browsesDays: Bool {
        !store.dialSettings.currentTimeAtTop
    }

    /// The selected day offset, ignoring it while days can't be browsed.
    private var visibleDayOffset: Int {
        browsesDays ? dayOffset : 0
    }

    /// `now` moved to the selected day, keeping the time of day.
    private func day(at now: Date) -> Date {
        let offset = visibleDayOffset
        guard offset != 0 else { return now }
        return Calendar.current.date(byAdding: .day, value: offset, to: now) ?? now
    }

    private func content(now: Date) -> some View {
        let offset = visibleDayOffset
        let selectedDay = day(at: now)
        let daySegments = EventSegment.segments(for: store.events, on: selectedDay)
        let dialSegments = store.dialSettings.segments(for: store.events, at: selectedDay)
        let daylight = store.daylightSettings.daylight(on: selectedDay)
        let dayEvents = uniqueEvents(in: daySegments)
        let dayEventIDs = Set(dayEvents.map { $0.id })
        let others = store.events
            .filter { !dayEventIDs.contains($0.id) }
            .sorted(by: ClockEvent.listOrder)

        return List {
            Section {
                header(day: selectedDay, offset: offset, daylight: daylight, segments: dialSegments)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            }

            Section {
                if dayEvents.isEmpty {
                    Group {
                        if offset == 0 {
                            Text("No events today. Tap + to add one.")
                        } else {
                            Text("No events on this day. Tap + to add one.")
                        }
                    }
                    .foregroundStyle(.secondary)
                } else {
                    ForEach(dayEvents) { event in
                        eventButton(event)
                    }
                    .onDelete { offsets in
                        delete(offsets, from: dayEvents)
                    }
                }
            } header: {
                dayTitle(day: selectedDay, offset: offset)
            }

            if !others.isEmpty {
                Section {
                    ForEach(others) { event in
                        eventButton(event)
                    }
                    .onDelete { offsets in
                        delete(offsets, from: others)
                    }
                } header: {
                    Text("Other events")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func header(day: Date, offset: Int, daylight: Daylight, segments: [EventSegment]) -> some View {
        VStack(spacing: 14) {
            ClockFaceView(
                date: day,
                daylight: daylight,
                segments: segments,
                style: .full,
                currentTimeAtTop: store.dialSettings.currentTimeAtTop,
                showsHand: offset == 0
            ) { event in
                editorRequest = EditorRequest(event: event, isNew: false)
            }
            .padding(.horizontal, 8)
            .offset(x: swipeOffset)
            .opacity(1 - min(abs(swipeOffset) / 400, 0.5))

            VStack(spacing: 4) {
                Group {
                    if offset == 0 {
                        Text(verbatim: TimeText.string(date: day))
                    } else {
                        dayTitle(day: day, offset: offset)
                    }
                }
                .font(.system(size: 48, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.5)

                if browsesDays {
                    dayNavigation(day: day, offset: offset)
                } else {
                    dateText(day)
                }
            }

            DaylightSummaryView(daylight: daylight)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .contentShape(Rectangle())
        .simultaneousGesture(daySwipe, including: browsesDays ? .all : .subviews)
    }

    private func dateText(_ day: Date) -> some View {
        Text(day, format: .dateTime.weekday(.wide).day().month(.wide))
            .font(.subheadline)
            .foregroundStyle(.secondary)
    }

    /// The date between buttons for the previous and the next day.
    private func dayNavigation(day: Date, offset: Int) -> some View {
        HStack(spacing: 12) {
            Button {
                showDay(offset - 1)
            } label: {
                Label("Previous day", systemImage: "chevron.left")
                    .labelStyle(.iconOnly)
            }
            .disabled(offset == 0)
            .opacity(offset == 0 ? 0 : 1)

            dateText(day)

            Button {
                showDay(offset + 1)
            } label: {
                Label("Next day", systemImage: "chevron.right")
                    .labelStyle(.iconOnly)
            }
        }
        .font(.subheadline.weight(.semibold))
        .buttonStyle(.borderless)
    }

    /// "Today", "Tomorrow" or the weekday of the selected day.
    private func dayTitle(day: Date, offset: Int) -> Text {
        switch offset {
        case 0:
            return Text("Today")
        case 1:
            return Text("Tomorrow")
        default:
            let weekday = day.formatted(.dateTime.weekday(.wide))
            return Text(verbatim: weekday.capitalized(with: Locale.current))
        }
    }

    /// Swipe right to left for the next day, left to right for the previous one (not before today).
    private var daySwipe: some Gesture {
        DragGesture(minimumDistance: 20)
            .onChanged { value in
                let width = value.translation.width
                guard abs(width) > abs(value.translation.height) else { return }
                // Resist when there is no previous day to go to.
                swipeOffset = dayOffset == 0 && width > 0 ? width / 4 : width
            }
            .onEnded { value in
                let width = value.predictedEndTranslation.width
                let isHorizontal = abs(value.translation.width) > abs(value.translation.height)
                if isHorizontal && width < -swipeThreshold {
                    showDay(dayOffset + 1)
                } else if isHorizontal && width > swipeThreshold && dayOffset > 0 {
                    showDay(dayOffset - 1)
                } else {
                    withAnimation(.snappy) {
                        swipeOffset = 0
                    }
                }
            }
    }

    /// Moves to another day. The new day slides in from the side the swipe came from.
    private func showDay(_ offset: Int) {
        let target = max(offset, 0)
        guard target != dayOffset else {
            withAnimation(.snappy) {
                swipeOffset = 0
            }
            return
        }
        let entry: CGFloat = target > dayOffset ? 120 : -120
        var transaction = Transaction()
        transaction.disablesAnimations = true
        withTransaction(transaction) {
            dayOffset = target
            swipeOffset = entry
        }
        DispatchQueue.main.async {
            withAnimation(.snappy) {
                swipeOffset = 0
            }
        }
    }

    private func eventButton(_ event: ClockEvent) -> some View {
        Button {
            editorRequest = EditorRequest(event: event, isNew: false)
        } label: {
            EventRow(event: event)
        }
        .foregroundStyle(.primary)
    }

    private func uniqueEvents(in segments: [EventSegment]) -> [ClockEvent] {
        var seen = Set<UUID>()
        var result: [ClockEvent] = []
        for segment in segments {
            if seen.insert(segment.event.id).inserted {
                result.append(segment.event)
            }
        }
        return result
    }

    private func delete(_ offsets: IndexSet, from events: [ClockEvent]) {
        for index in offsets {
            store.delete(events[index])
        }
    }

    /// Keeps sunrise and sunset current when the user travels (only if access was already granted).
    private func refreshLocation() {
        guard store.daylightSettings.source == .location, locationService.isAuthorized else { return }
        locationService.requestLocation(prompting: false) { coordinate in
            var updated = store.daylightSettings
            updated.setLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            store.updateDaylight(updated)
        }
    }
}

/// A request to show the event editor.
struct EditorRequest: Identifiable {
    let event: ClockEvent
    let isNew: Bool

    var id: UUID { event.id }
}
