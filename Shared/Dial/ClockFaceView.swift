import SwiftUI

/// The circular 24-hour clock: the sky (day and night) around the dial, events as pie slices
/// and a single hand for the current time. 24 is at the top, 6 on the right, 12 at the bottom
/// and 18 on the left, unless `currentTimeAtTop` turns the dial so the hand always points up.
///
/// With the current time at the top, the quarter between the left and the top is the past
/// (`DialSettings.pastHoursAtTop`) and the rest, clockwise from the top, is the future: past
/// events are faded and a dashed line marks where the window of 24 hours begins and ends.
struct ClockFaceView: View {
    let date: Date
    let daylight: Daylight
    let segments: [EventSegment]
    var style: ClockFaceStyle = .full
    /// Turns the dial so the current time stays at the top: the hand points up and the hours
    /// move counterclockwise as the day goes by.
    var currentTimeAtTop: Bool = false
    /// Whether the hand is drawn. Off when the dial shows another day than today.
    var showsHand: Bool = true
    /// Called when the user taps an event slice. Ignored in widgets.
    var onSelectEvent: ((ClockEvent) -> Void)? = nil

    var body: some View {
        GeometryReader { proxy in
            let side = min(proxy.size.width, proxy.size.height)
            dial(side: side)
                .frame(width: side, height: side)
                .position(x: proxy.size.width / 2, y: proxy.size.height / 2)
        }
        .aspectRatio(1, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("24-hour clock"))
        .accessibilityValue(accessibilityValue)
    }

    private var accessibilityValue: Text {
        if showsHand {
            return Text(verbatim: TimeText.string(date: date))
        }
        return Text(date, format: .dateTime.weekday(.wide).day().month(.wide))
    }

    /// The hour drawn at the top of the dial.
    private var topHour: Double {
        currentTimeAtTop ? date.hourOfDay() : 0
    }

    private func dial(side: CGFloat) -> some View {
        let radius = side / 2
        let center = CGPoint(x: radius, y: radius)
        let slices = SliceLayout.slices(
            for: segments,
            innerRadius: style.eventInnerRadius,
            outerRadius: style.eventOuterRadius
        )
        return ZStack {
            Circle()
                .fill(SkyPalette.skyGradient(for: daylight, topHour: topHour))
            if style.showsSkyIcons {
                skyIcons(radius: radius, center: center)
            }
            if currentTimeAtTop {
                // The future at full strength, the past faded.
                events(slices, radius: radius, center: center)
                    .mask(windowSector(fromHour: topHour, toHour: topHour + 24 - DialSettings.pastHoursAtTop))
                events(slices, radius: radius, center: center)
                    .mask(windowSector(fromHour: topHour - DialSettings.pastHoursAtTop, toHour: topHour))
                    .opacity(0.4)
            } else {
                events(slices, radius: radius, center: center)
            }
            ticks(radius: radius)
            hourLabels(radius: radius, center: center)
            if currentTimeAtTop {
                windowEdge(radius: radius)
            }
            if showsHand {
                hand(radius: radius, center: center)
            }
            Circle()
                .strokeBorder(Color.black.opacity(0.12), lineWidth: max(0.5, radius * 0.01))
        }
        .contentShape(Circle())
        .onTapGesture { location in
            guard let onSelectEvent = onSelectEvent else { return }
            let polar = DialGeometry.polar(of: location, center: center, radius: radius, topHour: topHour)
            if let slice = SliceLayout.slice(atHour: polar.hour, distance: polar.distance, in: slices) {
                onSelectEvent(slice.segment.event)
            }
        }
    }

    // MARK: - Layers

    private func events(_ slices: [DialSlice], radius: CGFloat, center: CGPoint) -> some View {
        ZStack {
            eventSlices(slices, radius: radius)
            if style.showsEventLabels {
                eventLabels(slices, radius: radius, center: center)
            }
        }
    }

    /// A wedge of the whole dial between two hours, used to split the past from the future.
    private func windowSector(fromHour startHour: Double, toHour endHour: Double) -> DialSectorShape {
        DialSectorShape(startHour: startHour, endHour: endHour, innerRadius: 0, outerRadius: 1, topHour: topHour)
    }

    /// The dashed line on the left where the past begins and the future ends.
    private func windowEdge(radius: CGFloat) -> some View {
        let hour = topHour - DialSettings.pastHoursAtTop
        let lineWidth = max(1, radius * 0.012)
        return DialRadialLineShape(
            hour: hour,
            innerRadius: style.eventInnerRadius,
            outerRadius: style.eventOuterRadius,
            topHour: topHour
        )
        .stroke(
            SkyPalette.ink(atHour: hour.positiveModulo(24), daylight: daylight).color.opacity(0.7),
            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round, dash: [lineWidth * 2.5, lineWidth * 2.5])
        )
    }

    @ViewBuilder
    private func skyIcons(radius: CGFloat, center: CGPoint) -> some View {
        let iconSize = radius * 0.12
        let iconRadius = radius * style.eventOuterRadius * 0.62
        if daylight.dayLength > 0 {
            Image(systemName: "sun.max.fill")
                .font(.system(size: iconSize))
                .foregroundStyle(SkyPalette.sun.color)
                .position(DialGeometry.point(
                    hour: daylight.middayHour,
                    radius: iconRadius,
                    center: center,
                    topHour: topHour
                ))
        }
        if daylight.dayLength < 24 {
            Image(systemName: "moon.stars.fill")
                .font(.system(size: iconSize))
                .foregroundStyle(SkyPalette.moon.color)
                .position(DialGeometry.point(
                    hour: daylight.midnightHour,
                    radius: iconRadius,
                    center: center,
                    topHour: topHour
                ))
        }
    }

    private func eventSlices(_ slices: [DialSlice], radius: CGFloat) -> some View {
        ForEach(slices) { slice in
            let shape = DialSectorShape(
                startHour: slice.startHour,
                endHour: slice.endHour,
                innerRadius: slice.innerRadius,
                outerRadius: slice.outerRadius,
                topHour: topHour
            )
            shape
                .fill(slice.segment.event.color.color.opacity(0.9))
                .overlay {
                    shape.stroke(Color.white.opacity(0.6), lineWidth: max(0.5, radius * 0.007))
                }
        }
    }

    private func ticks(radius: CGFloat) -> some View {
        let ink = SkyPalette.inkGradient(for: daylight, topHour: topHour)
        return ZStack {
            if style.showsMinorTicks {
                DialTicksShape(count: 96, innerRadius: 0.955, outerRadius: 0.985, skipping: 4, topHour: topHour)
                    .stroke(ink, lineWidth: max(0.5, radius * 0.005))
                    .opacity(0.6)
            }
            DialTicksShape(count: 24, innerRadius: 0.925, outerRadius: 0.985, skipping: 6, topHour: topHour)
                .stroke(ink, lineWidth: max(0.75, radius * 0.011))
            DialTicksShape(count: 4, innerRadius: 0.895, outerRadius: 0.985, topHour: topHour)
                .stroke(ink, lineWidth: max(1, radius * 0.022))
        }
    }

    private func hourLabels(radius: CGFloat, center: CGPoint) -> some View {
        ForEach(visibleHours, id: \.self) { hour in
            let isCardinal = hour % 6 == 0
            Text(verbatim: hour == 0 ? "24" : "\(hour)")
                .font(.system(
                    size: radius * (isCardinal ? style.cardinalFontSize : style.minorFontSize),
                    weight: isCardinal ? .bold : .medium,
                    design: .rounded
                ))
                .monospacedDigit()
                .foregroundStyle(SkyPalette.ink(atHour: Double(hour), daylight: daylight).color)
                .position(DialGeometry.point(
                    hour: Double(hour),
                    radius: radius * style.labelRadius,
                    center: center,
                    topHour: topHour
                ))
        }
    }

    private var visibleHours: [Int] {
        switch style.hourLabels {
        case .all:
            return Array(0..<24)
        case .cardinal:
            return [0, 6, 12, 18]
        case .none:
            return []
        }
    }

    private func eventLabels(_ slices: [DialSlice], radius: CGFloat, center: CGPoint) -> some View {
        ForEach(slices.filter { $0.spanHours >= 1 }) { slice in
            let bandRadius = slice.innerRadius + (slice.outerRadius - slice.innerRadius) * 0.6
            let arcLength = bandRadius * radius * CGFloat(DialGeometry.radians(forHour: slice.spanHours))
            let width = min(arcLength * 0.9, radius * 0.55)
            let fontSize = min(radius * 0.068, (slice.outerRadius - slice.innerRadius) * radius * 0.42)
            Text(slice.segment.event.title)
                .font(.system(size: fontSize, weight: .semibold, design: .rounded))
                .lineLimit(1)
                .minimumScaleFactor(0.5)
                .foregroundStyle(slice.segment.event.color.prefersDarkText ? SkyPalette.dayInk.color : Color.white)
                .frame(width: width)
                .position(DialGeometry.point(
                    hour: slice.midHour,
                    radius: bandRadius * radius,
                    center: center,
                    topHour: topHour
                ))
        }
    }

    private func hand(radius: CGFloat, center: CGPoint) -> some View {
        let hour = date.hourOfDay()
        let width = radius * style.handWidth
        let outline = width + max(1.5, radius * 0.014)
        let tip = DialGeometry.point(hour: hour, radius: radius * 0.9, center: center, topHour: topHour)
        let handColor = SkyPalette.hand.color
        return ZStack {
            DialHandShape(hour: hour, length: 0.9, topHour: topHour)
                .stroke(Color.white.opacity(0.9), style: StrokeStyle(lineWidth: outline, lineCap: .round))
            DialHandShape(hour: hour, length: 0.9, topHour: topHour)
                .stroke(handColor, style: StrokeStyle(lineWidth: width, lineCap: .round))
            Circle()
                .fill(handColor)
                .frame(width: width * 2.2, height: width * 2.2)
                .position(tip)
            Circle()
                .fill(handColor)
                .overlay {
                    Circle().fill(Color.white).padding(width * 0.9)
                }
                .frame(width: width * 3.4, height: width * 3.4)
                .position(center)
        }
    }
}
