import SwiftUI
import WidgetKit

/// The 24-hour clock on the Home Screen (small, medium, large) and the Lock Screen (circular).
struct ClockWidget: Widget {
    let kind = "ClockWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: ClockTimelineProvider()) { entry in
            ClockWidgetView(entry: entry)
        }
        .configurationDisplayName(Text("24H Clock"))
        .description(Text("Your day on a 24-hour dial, with your events as slices."))
        .supportedFamilies([.accessoryCircular, .systemSmall, .systemMedium, .systemLarge])
    }
}

struct ClockWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: ClockEntry

    var body: some View {
        switch family {
        case .accessoryCircular:
            dial(style: .mini)
                .containerBackground(for: .widget) {
                    AccessoryWidgetBackground()
                }
        case .systemMedium:
            mediumLayout
                .containerBackground(for: .widget) {
                    background
                }
        case .systemLarge:
            largeLayout
                .containerBackground(for: .widget) {
                    background
                }
        default:
            dial(style: .compact)
                .containerBackground(for: .widget) {
                    background
                }
        }
    }

    // MARK: - Layouts

    private var mediumLayout: some View {
        HStack(spacing: 14) {
            dial(style: .compact)
            VStack(alignment: .leading, spacing: 4) {
                Text(entry.date, style: .time)
                    .font(.system(size: 28, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .environment(\.locale, Locale.twentyFourHour)
                Text(entry.date, format: .dateTime.weekday(.wide).day().month())
                    .font(.caption)
                    .foregroundStyle(secondaryInk)
                Spacer(minLength: 2)
                agenda
                DaylightSummaryView(daylight: daylight)
                    .font(.caption2)
                    .foregroundStyle(secondaryInk)
            }
            .foregroundStyle(ink)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var largeLayout: some View {
        VStack(spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Text(entry.date, format: .dateTime.weekday(.wide).day().month())
                    .font(.headline)
                Spacer(minLength: 8)
                Text(entry.date, style: .time)
                    .font(.headline.monospacedDigit())
                    .environment(\.locale, Locale.twentyFourHour)
            }
            .foregroundStyle(ink)
            dial(style: .full)
            HStack(alignment: .center) {
                agenda
                Spacer(minLength: 8)
                DaylightSummaryView(daylight: daylight)
                    .font(.caption)
                    .foregroundStyle(secondaryInk)
            }
            .foregroundStyle(ink)
        }
    }

    private func dial(style: ClockFaceStyle) -> some View {
        ClockFaceView(
            date: entry.date,
            daylight: daylight,
            segments: entry.snapshot.dial.segments(
                for: entry.snapshot.events,
                calendarEvents: entry.calendarEvents,
                at: entry.date
            ),
            style: style,
            currentTimeAtTop: entry.snapshot.dial.currentTimeAtTop
        )
            .shadow(color: Color.black.opacity(0.2), radius: 3, y: 1)
    }

    @ViewBuilder
    private var agenda: some View {
        let dayAgenda = DayAgenda(segments: segments, date: entry.date)
        VStack(alignment: .leading, spacing: 3) {
            if let current = dayAgenda.current {
                agendaLine(
                    segment: current,
                    detail: Text("Until \(TimeText.string(minuteOfDay: current.endMinute))")
                )
            }
            if let next = dayAgenda.next {
                agendaLine(
                    segment: next,
                    detail: Text("Next at \(TimeText.string(minuteOfDay: next.startMinute))")
                )
            }
            if dayAgenda.current == nil && dayAgenda.next == nil {
                Text("No more events today")
                    .font(.caption)
                    .foregroundStyle(secondaryInk)
            }
        }
    }

    private func agendaLine(segment: EventSegment, detail: Text) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(segment.event.color)
                .frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 0) {
                Text(segment.event.title)
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
                detail
                    .font(.caption2)
                    .foregroundStyle(secondaryInk)
                    .lineLimit(1)
            }
        }
    }

    // MARK: - Colors and data

    private var hour: Double { entry.date.hourOfDay() }
    private var daylight: Daylight { entry.snapshot.daylight.daylight(on: entry.date) }
    /// Today's segments, for the agenda. The dial asks `DialSettings` for its own.
    private var segments: [EventSegment] {
        EventSegment.segments(for: entry.snapshot.events, calendarEvents: entry.calendarEvents, on: entry.date)
    }

    /// The sky of the current hour, so the widget itself is dark at night and light by day.
    private var background: some View {
        let sky = SkyPalette.sky(atHour: hour, daylight: daylight)
        let white = RGBColor(red: 1, green: 1, blue: 1)
        let black = RGBColor(red: 0, green: 0, blue: 0)
        return LinearGradient(
            colors: [sky.mixed(with: white, amount: 0.08).color, sky.mixed(with: black, amount: 0.18).color],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private var ink: Color { SkyPalette.ink(atHour: hour, daylight: daylight).color }
    private var secondaryInk: Color { ink.opacity(0.72) }
}
