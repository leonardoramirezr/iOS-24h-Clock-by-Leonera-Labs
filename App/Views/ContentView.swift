import SwiftUI

/// The main screen: the 24-hour clock with today's events, followed by every other event.
struct ContentView: View {
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var locationService: LocationService
    @Environment(\.scenePhase) private var scenePhase

    @State private var editorRequest: EditorRequest?
    @State private var isShowingSettings = false

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { context in
                content(now: context.date)
            }
            .navigationTitle(Text("24H Clock"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        isShowingSettings = true
                    } label: {
                        Label("Settings", systemImage: "gearshape")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        let draft = ClockEvent.draft(at: Date(), color: store.suggestedColor())
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
    }

    private func content(now: Date) -> some View {
        let segments = EventSegment.segments(for: store.events, on: now)
        let daylight = store.daylightSettings.daylight(on: now)
        let today = uniqueEvents(in: segments)
        let todayIDs = Set(today.map { $0.id })
        let others = store.events
            .filter { !todayIDs.contains($0.id) }
            .sorted(by: ClockEvent.listOrder)

        return List {
            Section {
                header(now: now, daylight: daylight, segments: segments)
                    .frame(maxWidth: .infinity)
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 4, leading: 0, bottom: 8, trailing: 0))
            }

            Section {
                if today.isEmpty {
                    Text("No events today. Tap + to add one.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(today) { event in
                        eventButton(event)
                    }
                    .onDelete { offsets in
                        delete(offsets, from: today)
                    }
                }
            } header: {
                Text("Today")
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

    private func header(now: Date, daylight: Daylight, segments: [EventSegment]) -> some View {
        VStack(spacing: 14) {
            ClockFaceView(date: now, daylight: daylight, segments: segments, style: .full) { event in
                editorRequest = EditorRequest(event: event, isNew: false)
            }
            .padding(.horizontal, 8)

            VStack(spacing: 4) {
                Text(verbatim: TimeText.string(date: now))
                    .font(.system(size: 48, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                Text(now, format: .dateTime.weekday(.wide).day().month(.wide))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            DaylightSummaryView(daylight: daylight)
                .font(.subheadline)
                .foregroundStyle(.secondary)
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
