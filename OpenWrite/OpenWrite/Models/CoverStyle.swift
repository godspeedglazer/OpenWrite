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
    case teal
    case plum
    case sunset
    case arctic
    case bronze
    case moss
    case solidInk
    case solidStone
    case solidSand
    case solidBlush
    case solidMint
    case solidSky

    var id: String { rawValue }

    /// Gradient presets shown first in the cover picker; solids follow.
    static var gradientPresets: [CoverStyle] {
        allCases.filter { !$0.isSolid }
    }

    static var solidPresets: [CoverStyle] {
        allCases.filter(\.isSolid)
    }

    var isSolid: Bool {
        switch self {
        case .solidInk, .solidStone, .solidSand, .solidBlush, .solidMint, .solidSky:
            return true
        default:
            return false
        }
    }

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
        case .teal: return "Teal"
        case .plum: return "Plum"
        case .sunset: return "Sunset"
        case .arctic: return "Arctic"
        case .bronze: return "Bronze"
        case .moss: return "Moss"
        case .solidInk: return "Ink"
        case .solidStone: return "Stone"
        case .solidSand: return "Sand"
        case .solidBlush: return "Blush"
        case .solidMint: return "Mint"
        case .solidSky: return "Sky"
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
        case .teal:
            return [Color(red: 0.12, green: 0.62, blue: 0.68), Color(red: 0.28, green: 0.82, blue: 0.78)]
        case .plum:
            return [Color(red: 0.42, green: 0.22, blue: 0.58), Color(red: 0.68, green: 0.35, blue: 0.72)]
        case .sunset:
            return [Color(red: 0.95, green: 0.42, blue: 0.38), Color(red: 0.98, green: 0.62, blue: 0.45)]
        case .arctic:
            return [Color(red: 0.78, green: 0.90, blue: 0.98), Color(red: 0.55, green: 0.72, blue: 0.95)]
        case .bronze:
            return [Color(red: 0.62, green: 0.42, blue: 0.28), Color(red: 0.85, green: 0.62, blue: 0.38)]
        case .moss:
            return [Color(red: 0.32, green: 0.52, blue: 0.32), Color(red: 0.55, green: 0.68, blue: 0.38)]
        case .solidInk:
            return solid(Color(red: 0.12, green: 0.13, blue: 0.16))
        case .solidStone:
            return solid(Color(red: 0.55, green: 0.56, blue: 0.58))
        case .solidSand:
            return solid(Color(red: 0.94, green: 0.90, blue: 0.82))
        case .solidBlush:
            return solid(Color(red: 0.96, green: 0.82, blue: 0.86))
        case .solidMint:
            return solid(Color(red: 0.82, green: 0.94, blue: 0.88))
        case .solidSky:
            return solid(Color(red: 0.82, green: 0.90, blue: 0.98))
        }
    }

    private func solid(_ color: Color) -> [Color] {
        [color, color.opacity(0.92), color.opacity(0.88)]
    }
}
