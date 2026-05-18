import Foundation

/// User-selectable visual themes for the OpenWrite shell.
enum ThemeID: String, CaseIterable, Identifiable, Codable, Sendable {
    case openWriteLight
    case openWriteDark
    case anytypeCalm
    case reorSlate
    case logseqInk
    case massCodeMono
    case midnight
    case solarizedWarm
    case highContrast
    case lavenderMist
    case parchmentStudio
    case nordFrost
    case emberDusk

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .openWriteLight: return "OpenWrite Light"
        case .openWriteDark: return "OpenWrite Dark"
        case .anytypeCalm: return "Anytype Calm"
        case .reorSlate: return "Reor Slate"
        case .logseqInk: return "Logseq Ink"
        case .massCodeMono: return "MassCode Mono"
        case .midnight: return "Midnight"
        case .solarizedWarm: return "Solarized Warm"
        case .highContrast: return "High Contrast"
        case .lavenderMist: return "Lavender Mist"
        case .parchmentStudio: return "Parchment Studio"
        case .nordFrost: return "Nord Frost"
        case .emberDusk: return "Ember Dusk"
        }
    }

    var shortDescription: String {
        switch self {
        case .openWriteLight:
            return "Default bright workbench with cool sidebar rail."
        case .openWriteDark:
            return "Neutral dark surfaces tuned for long evening sessions."
        case .anytypeCalm:
            return "Warm gray chrome and soft paper canvas — object-first calm."
        case .reorSlate:
            return "Deep blue-gray shell with violet assist accents."
        case .logseqInk:
            return "Outliner-friendly forest tint and emerald links."
        case .massCodeMono:
            return "Editor-dark neutrals with amber highlights — snippet-manager mood."
        case .midnight:
            return "Ink-blue night mode with crisp cyan highlights."
        case .solarizedWarm:
            return "Solarized cream canvas with warm orange accents."
        case .highContrast:
            return "Maximum legibility for low-vision and bright rooms."
        case .lavenderMist:
            return "Soft lilac rail with muted violet accents."
        case .parchmentStudio:
            return "Warm editorial paper with terracotta highlights."
        case .nordFrost:
            return "Cool polar night with ice-blue links."
        case .emberDusk:
            return "Smoky plum canvas with ember orange accents."
        }
    }

    /// Page hero gradient preset that matches this theme, when one exists.
    var suggestedPageCover: CoverStyle? {
        switch self {
        case .solarizedWarm: return .solarizedHeader
        case .anytypeCalm: return .anytypeCalm
        default: return nil
        }
    }

    /// Drives system control chrome where themes are predominantly dark.
    var prefersDarkAppearance: Bool {
        switch self {
        case .openWriteLight, .anytypeCalm, .solarizedWarm, .highContrast, .lavenderMist, .parchmentStudio:
            return false
        case .openWriteDark, .reorSlate, .logseqInk, .massCodeMono, .midnight, .nordFrost, .emberDusk:
            return true
        }
    }

    /// Maps deprecated persisted raw values to current cases.
    static func resolved(fromPersistedRawValue raw: String) -> ThemeID? {
        switch raw {
        case "reorDark": return .reorSlate
        case "logseqGreen": return .logseqInk
        default: return ThemeID(rawValue: raw)
        }
    }
}
