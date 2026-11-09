import SwiftUI

/// The details of an event from a connected calendar. Calendar events are read-only in the
/// app, so this view links to the Calendar app to change them.
struct CalendarEventDetailView: View {
    let event: CalendarEvent

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: event.displayTitle)
                            .font(.title2.weight(.semibold))
                        HStack(spacing: 6) {
                            RoundedRectangle(cornerRadius: 3, style: .continuous)
                                .fill(event.color.color)
                                .frame(width: 12, height: 12)
                            Text(verbatim: event.calendarTitle)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.vertical, 4)
                }

                Section {
                    if event.isAllDay {
                        LabeledContent("Date") {
                            Text(verbatim: allDayDates)
                        }
                        LabeledContent("Time") {
                            Text("All day")
                        }
                    } else {
                        LabeledContent("Starts") {
                            Text(verbatim: dateAndTime(event.start))
                                .monospacedDigit()
                        }
                        LabeledContent("Ends") {
                            Text(verbatim: dateAndTime(event.end))
                                .monospacedDigit()
                        }
                        LabeledContent("Duration") {
                            Text(verbatim: TimeText.duration(minutes: event.durationMinutes, includesDays: true))
                        }
                    }
                }

                if let location = nonEmpty(event.location) {
                    Section {
                        Text(verbatim: location)
                            .textSelection(.enabled)
                    } header: {
                        Text("Location")
                    }
                }

                if let notes = nonEmpty(event.notes) {
                    Section {
                        Text(verbatim: notes)
                            .textSelection(.enabled)
                    } header: {
                        Text("Notes")
                    }
                }

                Section {
                    Button {
                        if let url = calendarAppURL {
                            openURL(url)
                        }
                    } label: {
                        Label("Open in Calendar", systemImage: "calendar")
                    }
                } footer: {
                    Text("This event comes from your calendar. Change it in the Calendar app.")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(Text("Calendar Event"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }

    /// Opens the Calendar app on the day of the event.
    private var calendarAppURL: URL? {
        URL(string: "calshow:\(event.start.timeIntervalSinceReferenceDate)")
    }

    /// "Sat, Nov 8, 09:00": the date with the 24-hour time.
    private func dateAndTime(_ date: Date) -> String {
        let day = date.formatted(.dateTime.weekday(.abbreviated).day().month(.abbreviated))
        return "\(day), \(TimeText.string(date: date))"
    }

    /// The day of an all-day event, or its first and last days.
    private var allDayDates: String {
        let format: Date.FormatStyle = .dateTime.weekday(.abbreviated).day().month(.abbreviated)
        let first = event.start.formatted(format)
        guard event.spansSeveralDays else { return first }
        return "\(first) – \(event.lastMoment.formatted(format))"
    }

    private func nonEmpty(_ text: String?) -> String? {
        guard let trimmed = text?.trimmingCharacters(in: .whitespacesAndNewlines), !trimmed.isEmpty else {
            return nil
        }
        return trimmed
    }
}
