import Foundation

/// How the dial is drawn.
struct DialSettings: Codable, Hashable {
    /// Turns the dial so the current time stays at the top instead of 24. The hand always
    /// points up and the hours move counterclockwise as time goes by.
    var currentTimeAtTop: Bool = false

    init() {}

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        currentTimeAtTop = (try? container.decode(Bool.self, forKey: .currentTimeAtTop)) ?? false
    }

    private enum CodingKeys: String, CodingKey {
        case currentTimeAtTop
    }
}
