import CoreGraphics

/// What the dial shows at a given size. Radii and sizes are fractions of the dial radius.
struct ClockFaceStyle {
    enum HourLabels {
        /// Every hour, with 24, 6, 12 and 18 emphasized.
        case all
        /// Only 24 (top), 6 (right), 12 (bottom) and 18 (left).
        case cardinal
        case none
    }

    var hourLabels: HourLabels
    var showsMinorTicks: Bool
    var showsEventLabels: Bool
    var showsSkyIcons: Bool
    var labelRadius: CGFloat
    var cardinalFontSize: CGFloat
    var minorFontSize: CGFloat
    var eventInnerRadius: CGFloat
    var eventOuterRadius: CGFloat
    var handWidth: CGFloat

    /// The app and the large widget.
    static let full = ClockFaceStyle(
        hourLabels: .all,
        showsMinorTicks: true,
        showsEventLabels: true,
        showsSkyIcons: true,
        labelRadius: 0.835,
        cardinalFontSize: 0.105,
        minorFontSize: 0.062,
        eventInnerRadius: 0.1,
        eventOuterRadius: 0.73,
        handWidth: 0.022
    )

    /// Small and medium widgets.
    static let compact = ClockFaceStyle(
        hourLabels: .cardinal,
        showsMinorTicks: false,
        showsEventLabels: false,
        showsSkyIcons: true,
        labelRadius: 0.79,
        cardinalFontSize: 0.16,
        minorFontSize: 0.1,
        eventInnerRadius: 0.1,
        eventOuterRadius: 0.66,
        handWidth: 0.04
    )

    /// The circular Lock Screen widget.
    static let mini = ClockFaceStyle(
        hourLabels: .none,
        showsMinorTicks: false,
        showsEventLabels: false,
        showsSkyIcons: false,
        labelRadius: 0.8,
        cardinalFontSize: 0.2,
        minorFontSize: 0.1,
        eventInnerRadius: 0.12,
        eventOuterRadius: 0.86,
        handWidth: 0.08
    )
}
