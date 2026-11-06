import Foundation
import os
import WidgetKit

/// Owns the user's events and daylight settings, saves them, and keeps the widget in sync.
final class EventStore: ObservableObject {
    @Published private(set) var snapshot: AppSnapshot

    private let fileURL: URL
    private let logger = Logger(subsystem: "com.leonardoramirezr.24hclock", category: "EventStore")

    init() {
        let directory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let url = directory.appendingPathComponent("snapshot.json")
        let saved = EventStore.readSnapshot(at: url)
        fileURL = url
        // The keychain copy survives reinstalls, so it restores events when the file is gone.
        snapshot = saved ?? SharedSnapshotStore.load() ?? .empty
        if saved != nil {
            SharedSnapshotStore.save(snapshot)
        }
    }

    var events: [ClockEvent] { snapshot.events }
    var daylightSettings: DaylightSettings { snapshot.daylight }

    func contains(_ event: ClockEvent) -> Bool {
        snapshot.events.contains { $0.id == event.id }
    }

    /// Adds the event, or replaces the stored event with the same identifier.
    func save(_ event: ClockEvent) {
        if let index = snapshot.events.firstIndex(where: { $0.id == event.id }) {
            snapshot.events[index] = event
        } else {
            snapshot.events.append(event)
        }
        persist()
    }

    func delete(_ event: ClockEvent) {
        snapshot.events.removeAll { $0.id == event.id }
        persist()
    }

    func updateDaylight(_ settings: DaylightSettings) {
        guard settings != snapshot.daylight else { return }
        snapshot.daylight = settings
        persist()
    }

    /// The first palette color that no event uses yet.
    func suggestedColor() -> EventColor {
        let used = Set(snapshot.events.map { $0.color })
        return EventColor.allCases.first { !used.contains($0) } ?? .blue
    }

    private func persist() {
        do {
            try FileManager.default.createDirectory(
                at: fileURL.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try JSONEncoder.snapshot.encode(snapshot).write(to: fileURL, options: .atomic)
        } catch {
            logger.error("Could not save events: \(error.localizedDescription, privacy: .public)")
        }
        if !SharedSnapshotStore.save(snapshot) {
            logger.error("Could not share events with the widget")
        }
        WidgetCenter.shared.reloadAllTimelines()
    }

    private static func readSnapshot(at url: URL) -> AppSnapshot? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(AppSnapshot.self, from: data)
    }
}
