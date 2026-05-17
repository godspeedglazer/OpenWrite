import SwiftUI

/// Page cover gradient preset — clean-room analogue to Anytype cover gallery stubs.
enum CoverStyle: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case coral
    case ocean
    case forest
    case grape
    case slate
    case rose
    case amber
    case midnight
    /// Warm paper + restrained blue — matches `ThemeID.anytypeCalm` banner feel.
    case anytypeCalm

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .coral: return "Coral"
        case .ocean: return "Ocean"
        case .forest: return "Forest"
        case .grape: return "Grape"
        case .slate: return "Slate"
        case .rose: return "Rose"
        case .amber: return "Amber"
        case .midnight: return "Midnight"
        case .anytypeCalm: return "Calm"
        }
    }

    /// Leading → trailing gradient stops for the page banner strip.
    func gradientColors(fallbackAccent: Color) -> [Color] {
        switch self {
        case .anytypeCalm:
            return [
                Color(red: 0.72, green: 0.80, blue: 0.92),
                Color(red: 0.94, green: 0.91, blue: 0.86),
                Color(red: 0.99, green: 0.98, blue: 0.95)
            ]
        case .coral:
            return [Color(red: 0.98, green: 0.45, blue: 0.42), Color(red: 0.95, green: 0.62, blue: 0.38)]
        case .ocean:
            return [Color(red: 0.22, green: 0.55, blue: 0.92), Color(red: 0.35, green: 0.78, blue: 0.88)]
        case .forest:
            return [Color(red: 0.18, green: 0.58, blue: 0.42), Color(red: 0.45, green: 0.72, blue: 0.38)]
        case .grape:
            return [Color(red: 0.52, green: 0.32, blue: 0.88), Color(red: 0.72, green: 0.42, blue: 0.82)]
        case .slate:
            return [Color(red: 0.38, green: 0.44, blue: 0.52), Color(red: 0.55, green: 0.58, blue: 0.65)]
        case .rose:
            return [Color(red: 0.92, green: 0.38, blue: 0.58), Color(red: 0.98, green: 0.55, blue: 0.68)]
        case .amber:
            return [Color(red: 0.95, green: 0.68, blue: 0.22), Color(red: 0.98, green: 0.82, blue: 0.42)]
        case .midnight:
            return [Color(red: 0.12, green: 0.14, blue: 0.28), Color(red: 0.28, green: 0.32, blue: 0.52)]
        }
    }
}
