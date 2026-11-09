import SwiftUI
import UIKit

/// Dial, calendar, sunrise and sunset preferences and information about the app.
struct SettingsView: View {
    @EnvironmentObject private var store: EventStore
    @EnvironmentObject private var locationService: LocationService
    @EnvironmentObject private var calendarService: CalendarService
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Toggle("Current time at top", isOn: currentTimeAtTop)
                } header: {
                    Text("Dial")
                } footer: {
                    Text("The dial turns so the current time is always at the top. The quarter between the left and the top shows the last 6 hours, and the next 18 hours follow clockwise from the top. When this is off, swipe the clock from right to left to see the next days.")
                }

                Section {
                    calendarRows
                } header: {
                    Text("Calendars")
                } footer: {
                    Text("Events from the calendars you connect are drawn on the clock and in the widgets, in the color of their calendar. All-day events are listed below the clock instead of on the dial.")
                }

                Section {
                    Picker("Source", selection: settings.source) {
                        Text("Manual").tag(DaylightSettings.Source.manual)
                        Text("Current location").tag(DaylightSettings.Source.location)
                    }
                    .pickerStyle(.segmented)

                    if store.daylightSettings.source == .manual {
                        DatePicker("Sunrise", selection: timeBinding(settings.sunriseMinute), displayedComponents: .hourAndMinute)
                        DatePicker("Sunset", selection: timeBinding(settings.sunsetMinute), displayedComponents: .hourAndMinute)
                    } else {
                        locationRows
                    }
                } header: {
                    Text("Sunrise and sunset")
                } footer: {
                    Text("Day hours are drawn light and night hours dark, with a soft blend at sunrise and sunset.")
                }

                Section {
                    DaylightSummaryView(daylight: store.daylightSettings.daylight(on: Date()))
                } header: {
                    Text("Today")
                }

                Section {
                    LabeledContent("Version", value: appVersion)
                } header: {
                    Text("About")
                } footer: {
                    Text(verbatim: "Leonera Labs")
                }
            }
            .navigationTitle(Text("Settings"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .onChange(of: store.daylightSettings.source) { _, source in
                if source == .location && !store.daylightSettings.hasLocation {
                    requestLocation()
                }
            }
        }
    }

    @ViewBuilder
    private var locationRows: some View {
        switch locationService.status {
        case .locating:
            HStack(spacing: 10) {
                ProgressView()
                Text("Locating…")
            }
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text("Location access is off. Turn it on in Settings to use local sunrise and sunset times.")
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    openAppSettings()
                }
                .buttonStyle(.borderless)
            }
        case .failed:
            Text("Could not get your location.")
                .foregroundStyle(.secondary)
        case .idle:
            EmptyView()
        }

        if let latitude = store.daylightSettings.latitude, let longitude = store.daylightSettings.longitude {
            LabeledContent("Location") {
                Text(verbatim: String(format: "%.1f°, %.1f°", latitude, longitude))
                    .monospacedDigit()
            }
        }

        Button("Update location") {
            requestLocation()
        }
        .disabled(locationService.status == .locating)
    }

    @ViewBuilder
    private var calendarRows: some View {
        switch calendarService.access {
        case .notDetermined:
            Button("Connect calendars") {
                connectCalendars()
            }
        case .denied:
            VStack(alignment: .leading, spacing: 8) {
                Text("Calendar access is off. Turn on full access in Settings to show your calendar events on the clock.")
                    .foregroundStyle(.secondary)
                Button("Open Settings") {
                    openAppSettings()
                }
                .buttonStyle(.borderless)
            }
        case .granted:
            NavigationLink {
                CalendarSelectionView()
            } label: {
                LabeledContent("Connected calendars", value: "\(connectedCalendarCount)")
            }
        }
    }

    /// Connected calendars that are still on the iPhone.
    private var connectedCalendarCount: Int {
        let ids = store.calendarSettings.calendarIDs
        return calendarService.calendars.filter { ids.contains($0.id) }.count
    }

    /// Asks for access to the calendars. The first time it is granted, every calendar is
    /// connected; the user can then turn off the ones they don't want.
    private func connectCalendars() {
        calendarService.requestAccess { granted in
            guard granted, !store.calendarSettings.isConnected else { return }
            var updated = store.calendarSettings
            updated.calendarIDs = Set(calendarService.calendars.map { $0.id })
            store.updateCalendars(updated)
        }
    }

    private func openAppSettings() {
        if let url = URL(string: UIApplication.openSettingsURLString) {
            openURL(url)
        }
    }

    private var settings: Binding<DaylightSettings> {
        Binding(
            get: { store.daylightSettings },
            set: { store.updateDaylight($0) }
        )
    }

    private var currentTimeAtTop: Binding<Bool> {
        Binding(
            get: { store.dialSettings.currentTimeAtTop },
            set: { isOn in
                var updated = store.dialSettings
                updated.currentTimeAtTop = isOn
                store.updateDial(updated)
            }
        )
    }

    private func timeBinding(_ minutes: Binding<Int>) -> Binding<Date> {
        Binding(
            get: { Date().atMinuteOfDay(minutes.wrappedValue) },
            set: { minutes.wrappedValue = $0.minuteOfDay() }
        )
    }

    private func requestLocation() {
        locationService.requestLocation(prompting: true) { coordinate in
            var updated = store.daylightSettings
            updated.setLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
            store.updateDaylight(updated)
        }
    }

    private var appVersion: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "–"
        return "\(version) (\(build))"
    }
}
