import SwiftUI

/// Creates or edits an event.
struct EventEditorView: View {
    @EnvironmentObject private var store: EventStore
    @Environment(\.dismiss) private var dismiss

    let isNew: Bool
    @State private var draft: ClockEvent
    @State private var repeats: Bool
    @State private var weekdays: Set<Int>
    @State private var day: Date
    @State private var isConfirmingDelete = false

    init(event: ClockEvent, isNew: Bool) {
        self.isNew = isNew
        _draft = State(initialValue: event)
        switch event.schedule {
        case .once(let stamp):
            _repeats = State(initialValue: false)
            _weekdays = State(initialValue: EventSchedule.allWeekdays)
            _day = State(initialValue: stamp.date())
        case .weekly(let days):
            _repeats = State(initialValue: true)
            _weekdays = State(initialValue: days)
            _day = State(initialValue: Date())
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Title", text: $draft.title)
                }

                Section {
                    DatePicker("Starts", selection: timeBinding(\.startMinute), displayedComponents: .hourAndMinute)
                    DatePicker("Ends", selection: timeBinding(\.endMinute), displayedComponents: .hourAndMinute)
                    LabeledContent("Duration") {
                        Text(verbatim: TimeText.duration(minutes: draft.durationMinutes))
                    }
                } header: {
                    Text("Time")
                } footer: {
                    if draft.startMinute == draft.endMinute {
                        Text("The end time must be different from the start time.")
                    } else if draft.endMinute < draft.startMinute {
                        Text("Ends the next day.")
                    }
                }

                Section {
                    colorGrid
                } header: {
                    Text("Color")
                }

                Section {
                    Toggle("Repeats", isOn: $repeats)
                    if repeats {
                        WeekdayPicker(selection: $weekdays)
                    } else {
                        DatePicker("Date", selection: $day, displayedComponents: .date)
                    }
                } header: {
                    Text("Repeat")
                }

                if !isNew {
                    Section {
                        Button("Delete Event", role: .destructive) {
                            isConfirmingDelete = true
                        }
                    }
                }
            }
            .navigationTitle(isNew ? Text("New Event") : Text("Edit Event"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .disabled(!isValid)
                }
            }
            .confirmationDialog(Text("Delete this event?"), isPresented: $isConfirmingDelete, titleVisibility: .visible) {
                Button("Delete Event", role: .destructive) {
                    store.delete(draft)
                    dismiss()
                }
            }
        }
    }

    private var colorGrid: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 6), spacing: 12) {
            ForEach(EventColor.allCases) { color in
                let isSelected = draft.color == color
                Button {
                    draft.color = color
                } label: {
                    Circle()
                        .fill(color.color)
                        .frame(width: 32, height: 32)
                        .overlay {
                            if isSelected {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 14, weight: .bold))
                                    .foregroundStyle(color.prefersDarkText ? Color.black : Color.white)
                            }
                        }
                }
                .buttonStyle(.borderless)
                .accessibilityLabel(Text(verbatim: color.localizedName))
                .accessibilityAddTraits(isSelected ? .isSelected : [])
            }
        }
        .padding(.vertical, 4)
    }

    private var isValid: Bool {
        let hasTitle = !draft.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasDays = !repeats || !weekdays.isEmpty
        return hasTitle && hasDays && draft.startMinute != draft.endMinute
    }

    private func timeBinding(_ keyPath: WritableKeyPath<ClockEvent, Int>) -> Binding<Date> {
        Binding(
            get: { Date().atMinuteOfDay(draft[keyPath: keyPath]) },
            set: { draft[keyPath: keyPath] = $0.minuteOfDay() }
        )
    }

    private func save() {
        var event = draft
        event.title = event.title.trimmingCharacters(in: .whitespacesAndNewlines)
        event.schedule = repeats ? .weekly(weekdays) : .once(DayStamp(date: day))
        store.save(event)
        dismiss()
    }
}
