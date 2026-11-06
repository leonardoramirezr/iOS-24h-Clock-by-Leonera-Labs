import SwiftUI

/// Sunrise and sunset times, or the polar day/night state.
struct DaylightSummaryView: View {
    let daylight: Daylight

    var body: some View {
        switch daylight {
        case let .normal(sunrise, sunset):
            let sunriseText = TimeText.string(hour: sunrise)
            let sunsetText = TimeText.string(hour: sunset)
            HStack(spacing: 14) {
                Label {
                    Text(verbatim: sunriseText)
                } icon: {
                    Image(systemName: "sunrise.fill")
                        .foregroundStyle(SkyPalette.twilight.color)
                }
                Label {
                    Text(verbatim: sunsetText)
                } icon: {
                    Image(systemName: "sunset.fill")
                        .foregroundStyle(SkyPalette.twilight.color)
                }
            }
            .monospacedDigit()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(Text("Sunrise \(sunriseText), sunset \(sunsetText)"))
        case .polarDay:
            Label("Polar day", systemImage: "sun.max.fill")
        case .polarNight:
            Label("Polar night", systemImage: "moon.stars.fill")
        }
    }
}
