import SwiftUI

/// The palette available for events.
enum EventColor: String, Codable, CaseIterable, Identifiable {
    case red
    case orange
    case yellow
    case green
    case mint
    case teal
    case blue
    case indigo
    case purple
    case pink
    case brown
    case gray

    var id: String { rawValue }

    /// Unknown values (for example from a newer version) fall back to blue.
    init(from decoder: Decoder) throws {
        let value = try decoder.singleValueContainer().decode(String.self)
        self = EventColor(rawValue: value) ?? .blue
    }

    var rgb: RGBColor {
        switch self {
        case .red: return RGBColor(hex: 0xE5484D)
        case .orange: return RGBColor(hex: 0xF27A2E)
        case .yellow: return RGBColor(hex: 0xF5C542)
        case .green: return RGBColor(hex: 0x46A758)
        case .mint: return RGBColor(hex: 0x5ED3B3)
        case .teal: return RGBColor(hex: 0x12A594)
        case .blue: return RGBColor(hex: 0x3E7BFA)
        case .indigo: return RGBColor(hex: 0x5B5BD6)
        case .purple: return RGBColor(hex: 0x9D5BD2)
        case .pink: return RGBColor(hex: 0xE5508E)
        case .brown: return RGBColor(hex: 0xA07553)
        case .gray: return RGBColor(hex: 0x8B8D98)
        }
    }

    var color: Color { rgb.color }

    /// Whether labels drawn on top of this color should be dark.
    var prefersDarkText: Bool { rgb.luminance > 0.6 }

    var localizedName: String {
        NSLocalizedString("color.\(rawValue)", comment: "Name of an event color")
    }
}
