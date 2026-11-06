import SwiftUI

/// One event in the lists below the clock.
struct EventRow: View {
    let event: ClockEvent

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(event.color.color)
                .frame(width: 14, height: 14)
            VStack(alignment: .leading, spacing: 2) {
                Text(event.displayTitle)
                    .font(.body.weight(.medium))
                Text(verbatim: timeRange)
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                Text(event.schedule.localizedDescription)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 0)
        }
        .padding(.vertical, 2)
        .contentShape(Rectangle())
    }

    private var timeRange: String {
        let start = TimeText.string(minuteOfDay: event.startMinute)
        let end = TimeText.string(minuteOfDay: event.endMinute)
        let duration = TimeText.duration(minutes: event.durationMinutes)
        return "\(start) – \(end) · \(duration)"
    }
}
