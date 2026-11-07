import SwiftUI

/// The iPhone's calendars, grouped by account, with a switch to connect each one to the clock.
struct CalendarSelectionView: View {
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var calendarService: CalendarService

    var body: some View {
        let groups = self.groups
        List {
            if groups.isEmpty {
                Text("No calendars found.")
                    .foregroundStyle(.secondary)
            }
            ForEach(groups) { group in
                Section {
                    ForEach(group.calendars) { info in
                        Toggle(isOn: isConnected(info.id)) {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(info.color.color)
                                    .frame(width: 12, height: 12)
                                Text(verbatim: info.title)
                            }
                        }
                    }
                } header: {
                    Text(verbatim: group.title)
                } footer: {
                    if group.id == groups.last?.id {
                        Text("Turn on the calendars whose events you want to see on the clock.")
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(Text("Calendars"))
        .navigationBarTitleDisplayMode(.inline)
    }

    /// Calendars of one account.
    private struct CalendarGroup: Identifiable {
        let id: String
        let title: String
        var calendars: [CalendarInfo]
    }

    /// The calendars grouped by account, keeping the order of `CalendarService.calendars`.
    private var groups: [CalendarGroup] {
        var result: [CalendarGroup] = []
        for info in calendarService.calendars {
            if let last = result.indices.last, result[last].id == info.sourceID {
                result[last].calendars.append(info)
            } else {
                result.append(CalendarGroup(id: info.sourceID, title: info.sourceTitle, calendars: [info]))
            }
        }
        return result
    }

    private func isConnected(_ id: String) -> Binding<Bool> {
        Binding(
            get: { store.calendarSettings.calendarIDs.contains(id) },
            set: { isOn in
                var updated = store.calendarSettings
                if isOn {
                    updated.calendarIDs.insert(id)
                } else {
                    updated.calendarIDs.remove(id)
                }
                store.updateCalendars(updated)
            }
        )
    }
}
