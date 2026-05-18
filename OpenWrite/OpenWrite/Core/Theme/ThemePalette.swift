import SwiftUI

/// Semantic colors for one OpenWrite theme. Values are sRGB; see `docs/design/Themes.md`.
struct ThemePalette: Equatable, Sendable {
    let background: Color
    let sidebarBackground: Color
    let workbenchChrome: Color
    let editorCanvas: Color
    let surface: Color
    let surfaceElevated: Color
    let selectionPill: Color
    let borderSubtle: Color
    let textPrimary: Color
    let textSecondary: Color
    let textTertiary: Color
    let accent: Color
    let separator: Color
    let danger: Color
    let success: Color
    let warning: Color

    /// Filled window title/toolbar strip — flush with navigation rail.
    var shellChrome: Color { sidebarBackground }

    var borderHairline: Color { borderSubtle.opacity(0.55) }
    var accentMuted: Color { accent.opacity(0.14) }
    var dangerMuted: Color { danger.opacity(0.12) }
    var wikilink: Color { accent }
    var codeBackground: Color { surface }
    var graphNode: Color { surfaceElevated }
    var graphEdge: Color { textTertiary }
    var graphNodeFocused: Color { accent }
    /// Text selection fill in block editors — visible on dark themes (e.g. Reor Slate).
    var selectionHighlight: Color { accent.opacity(0.38) }

    static func palette(for id: ThemeID) -> ThemePalette {
        switch id {
        case .openWriteLight: return openWriteLight
        case .openWriteDark: return openWriteDark
        case .anytypeCalm: return anytypeCalm
        case .reorSlate: return reorSlate
        case .logseqInk: return logseqInk
        case .massCodeMono: return massCodeMono
        case .midnight: return midnight
        case .solarizedWarm: return solarizedWarm
        case .highContrast: return highContrast
        case .lavenderMist: return lavenderMist
        case .parchmentStudio: return parchmentStudio
        case .nordFrost: return nordFrost
        case .emberDusk: return emberDusk
        }
    }

    // MARK: - Palettes

    private static let openWriteLight = ThemePalette(
        background: rgb(0.98, 0.98, 0.97),
        sidebarBackground: rgb(0.925, 0.929, 0.941),
        workbenchChrome: rgb(0.945, 0.947, 0.955),
        editorCanvas: rgb(1.0, 1.0, 1.0),
        surface: rgb(0.95, 0.95, 0.94),
        surfaceElevated: rgb(1.0, 1.0, 1.0),
        selectionPill: rgb(1.0, 1.0, 1.0),
        borderSubtle: rgb(0.90, 0.90, 0.92),
        textPrimary: rgb(0.10, 0.10, 0.10),
        textSecondary: rgb(0.45, 0.45, 0.47),
        textTertiary: rgb(0.60, 0.60, 0.62),
        accent: rgb(0.227, 0.420, 0.878),
        separator: rgb(0.88, 0.88, 0.87),
        danger: rgb(0.85, 0.22, 0.24),
        success: rgb(0.20, 0.62, 0.38),
        warning: rgb(0.85, 0.55, 0.12)
    )

    private static let openWriteDark = ThemePalette(
        background: rgb(0.11, 0.11, 0.12),
        sidebarBackground: rgb(0.12, 0.12, 0.13),
        workbenchChrome: rgb(0.10, 0.10, 0.11),
        editorCanvas: rgb(0.15, 0.15, 0.16),
        surface: rgb(0.15, 0.15, 0.16),
        surfaceElevated: rgb(0.18, 0.18, 0.19),
        selectionPill: rgb(0.20, 0.20, 0.21),
        borderSubtle: rgb(0.24, 0.24, 0.26),
        textPrimary: rgb(0.95, 0.95, 0.96),
        textSecondary: rgb(0.62, 0.62, 0.64),
        textTertiary: rgb(0.48, 0.48, 0.50),
        accent: rgb(0.35, 0.55, 0.95),
        separator: rgb(0.28, 0.28, 0.30),
        danger: rgb(0.95, 0.35, 0.38),
        success: rgb(0.35, 0.75, 0.50),
        warning: rgb(0.95, 0.70, 0.25)
    )

    /// Warm neutrals, restrained blue accent — Anytype-style calm density.
    private static let anytypeCalm = ThemePalette(
        background: rgb(0.965, 0.960, 0.952),
        sidebarBackground: rgb(0.928, 0.918, 0.902),
        workbenchChrome: rgb(0.948, 0.942, 0.932),
        editorCanvas: rgb(0.995, 0.992, 0.984),
        surface: rgb(0.94, 0.935, 0.925),
        surfaceElevated: rgb(1.0, 0.998, 0.992),
        selectionPill: rgb(1.0, 0.996, 0.988),
        borderSubtle: rgb(0.86, 0.84, 0.82),
        textPrimary: rgb(0.14, 0.13, 0.12),
        textSecondary: rgb(0.48, 0.46, 0.44),
        textTertiary: rgb(0.62, 0.58, 0.54),
        accent: rgb(0.28, 0.42, 0.78),
        separator: rgb(0.84, 0.82, 0.78),
        danger: rgb(0.82, 0.28, 0.30),
        success: rgb(0.22, 0.58, 0.40),
        warning: rgb(0.80, 0.52, 0.18)
    )

    /// Reor-inspired deep slate with violet assist highlights.
    private static let reorSlate = ThemePalette(
        background: rgb(0.09, 0.10, 0.14),
        sidebarBackground: rgb(0.11, 0.12, 0.17),
        workbenchChrome: rgb(0.08, 0.09, 0.12),
        editorCanvas: rgb(0.13, 0.14, 0.19),
        surface: rgb(0.14, 0.15, 0.20),
        surfaceElevated: rgb(0.17, 0.18, 0.24),
        selectionPill: rgb(0.20, 0.21, 0.28),
        borderSubtle: rgb(0.26, 0.28, 0.36),
        textPrimary: rgb(0.94, 0.94, 0.97),
        textSecondary: rgb(0.64, 0.66, 0.74),
        textTertiary: rgb(0.50, 0.52, 0.60),
        accent: rgb(0.58, 0.48, 0.95),
        separator: rgb(0.30, 0.32, 0.40),
        danger: rgb(0.95, 0.38, 0.42),
        success: rgb(0.40, 0.78, 0.58),
        warning: rgb(0.95, 0.68, 0.32)
    )

    /// Logseq-style dark green shell with emerald wikilinks.
    private static let logseqInk = ThemePalette(
        background: rgb(0.08, 0.11, 0.09),
        sidebarBackground: rgb(0.10, 0.14, 0.11),
        workbenchChrome: rgb(0.07, 0.10, 0.08),
        editorCanvas: rgb(0.11, 0.15, 0.12),
        surface: rgb(0.12, 0.16, 0.13),
        surfaceElevated: rgb(0.15, 0.20, 0.16),
        selectionPill: rgb(0.18, 0.24, 0.19),
        borderSubtle: rgb(0.22, 0.30, 0.24),
        textPrimary: rgb(0.92, 0.96, 0.93),
        textSecondary: rgb(0.58, 0.70, 0.62),
        textTertiary: rgb(0.44, 0.56, 0.48),
        accent: rgb(0.28, 0.78, 0.52),
        separator: rgb(0.24, 0.32, 0.26),
        danger: rgb(0.92, 0.40, 0.38),
        success: rgb(0.32, 0.82, 0.55),
        warning: rgb(0.90, 0.72, 0.28)
    )

    /// MassCode-inspired near-monochrome editor chrome with amber accents.
    private static let massCodeMono = ThemePalette(
        background: rgb(0.12, 0.12, 0.12),
        sidebarBackground: rgb(0.14, 0.14, 0.14),
        workbenchChrome: rgb(0.10, 0.10, 0.10),
        editorCanvas: rgb(0.16, 0.16, 0.16),
        surface: rgb(0.17, 0.17, 0.17),
        surfaceElevated: rgb(0.20, 0.20, 0.20),
        selectionPill: rgb(0.24, 0.24, 0.24),
        borderSubtle: rgb(0.30, 0.30, 0.30),
        textPrimary: rgb(0.92, 0.92, 0.90),
        textSecondary: rgb(0.62, 0.62, 0.60),
        textTertiary: rgb(0.48, 0.48, 0.46),
        accent: rgb(0.92, 0.68, 0.22),
        separator: rgb(0.34, 0.34, 0.34),
        danger: rgb(0.95, 0.38, 0.35),
        success: rgb(0.42, 0.72, 0.38),
        warning: rgb(0.94, 0.72, 0.28)
    )

    private static let midnight = ThemePalette(
        background: rgb(0.06, 0.07, 0.11),
        sidebarBackground: rgb(0.08, 0.09, 0.14),
        workbenchChrome: rgb(0.05, 0.06, 0.09),
        editorCanvas: rgb(0.10, 0.11, 0.16),
        surface: rgb(0.11, 0.12, 0.18),
        surfaceElevated: rgb(0.14, 0.15, 0.22),
        selectionPill: rgb(0.17, 0.18, 0.26),
        borderSubtle: rgb(0.22, 0.24, 0.34),
        textPrimary: rgb(0.93, 0.95, 0.98),
        textSecondary: rgb(0.60, 0.66, 0.78),
        textTertiary: rgb(0.46, 0.52, 0.64),
        accent: rgb(0.32, 0.78, 0.92),
        separator: rgb(0.26, 0.28, 0.38),
        danger: rgb(0.96, 0.42, 0.45),
        success: rgb(0.38, 0.80, 0.62),
        warning: rgb(0.94, 0.74, 0.30)
    )

    /// Solarized-inspired warm light palette (base3 paper, orange accent).
    private static let solarizedWarm = ThemePalette(
        background: rgb(0.992, 0.965, 0.890),
        sidebarBackground: rgb(0.976, 0.945, 0.865),
        workbenchChrome: rgb(0.984, 0.958, 0.878),
        editorCanvas: rgb(0.996, 0.978, 0.910),
        surface: rgb(0.968, 0.932, 0.848),
        surfaceElevated: rgb(1.0, 0.988, 0.928),
        selectionPill: rgb(1.0, 0.982, 0.902),
        borderSubtle: rgb(0.88, 0.82, 0.72),
        textPrimary: rgb(0.24, 0.22, 0.18),
        textSecondary: rgb(0.42, 0.48, 0.50),
        textTertiary: rgb(0.55, 0.58, 0.56),
        accent: rgb(0.80, 0.35, 0.10),
        separator: rgb(0.84, 0.78, 0.68),
        danger: rgb(0.78, 0.18, 0.16),
        success: rgb(0.52, 0.60, 0.12),
        warning: rgb(0.72, 0.52, 0.08)
    )

    private static let highContrast = ThemePalette(
        background: rgb(1.0, 1.0, 1.0),
        sidebarBackground: rgb(0.94, 0.94, 0.94),
        workbenchChrome: rgb(0.96, 0.96, 0.96),
        editorCanvas: rgb(1.0, 1.0, 1.0),
        surface: rgb(0.98, 0.98, 0.98),
        surfaceElevated: rgb(1.0, 1.0, 1.0),
        selectionPill: rgb(0.88, 0.88, 0.88),
        borderSubtle: rgb(0.0, 0.0, 0.0),
        textPrimary: rgb(0.0, 0.0, 0.0),
        textSecondary: rgb(0.15, 0.15, 0.15),
        textTertiary: rgb(0.35, 0.35, 0.35),
        accent: rgb(0.0, 0.35, 0.75),
        separator: rgb(0.0, 0.0, 0.0),
        danger: rgb(0.75, 0.0, 0.0),
        success: rgb(0.0, 0.45, 0.20),
        warning: rgb(0.65, 0.40, 0.0)
    )

    private static let lavenderMist = ThemePalette(
        background: rgb(0.98, 0.97, 0.99),
        sidebarBackground: rgb(0.94, 0.92, 0.97),
        workbenchChrome: rgb(0.96, 0.95, 0.98),
        editorCanvas: rgb(1.0, 0.99, 1.0),
        surface: rgb(0.95, 0.93, 0.97),
        surfaceElevated: rgb(1.0, 0.998, 1.0),
        selectionPill: rgb(1.0, 0.99, 1.0),
        borderSubtle: rgb(0.88, 0.86, 0.92),
        textPrimary: rgb(0.16, 0.14, 0.20),
        textSecondary: rgb(0.48, 0.44, 0.54),
        textTertiary: rgb(0.62, 0.58, 0.66),
        accent: rgb(0.52, 0.38, 0.78),
        separator: rgb(0.86, 0.84, 0.90),
        danger: rgb(0.82, 0.26, 0.32),
        success: rgb(0.28, 0.58, 0.42),
        warning: rgb(0.78, 0.52, 0.18)
    )

    private static let parchmentStudio = ThemePalette(
        background: rgb(0.98, 0.96, 0.92),
        sidebarBackground: rgb(0.94, 0.90, 0.84),
        workbenchChrome: rgb(0.96, 0.93, 0.88),
        editorCanvas: rgb(1.0, 0.98, 0.94),
        surface: rgb(0.94, 0.90, 0.84),
        surfaceElevated: rgb(1.0, 0.98, 0.95),
        selectionPill: rgb(1.0, 0.97, 0.92),
        borderSubtle: rgb(0.86, 0.80, 0.72),
        textPrimary: rgb(0.18, 0.14, 0.10),
        textSecondary: rgb(0.48, 0.42, 0.36),
        textTertiary: rgb(0.62, 0.54, 0.46),
        accent: rgb(0.78, 0.42, 0.28),
        separator: rgb(0.84, 0.78, 0.70),
        danger: rgb(0.80, 0.24, 0.22),
        success: rgb(0.32, 0.55, 0.32),
        warning: rgb(0.82, 0.58, 0.18)
    )

    private static let nordFrost = ThemePalette(
        background: rgb(0.10, 0.13, 0.18),
        sidebarBackground: rgb(0.12, 0.16, 0.22),
        workbenchChrome: rgb(0.08, 0.11, 0.15),
        editorCanvas: rgb(0.14, 0.18, 0.24),
        surface: rgb(0.15, 0.19, 0.26),
        surfaceElevated: rgb(0.18, 0.23, 0.30),
        selectionPill: rgb(0.22, 0.28, 0.36),
        borderSubtle: rgb(0.28, 0.34, 0.44),
        textPrimary: rgb(0.92, 0.95, 0.98),
        textSecondary: rgb(0.62, 0.70, 0.80),
        textTertiary: rgb(0.48, 0.56, 0.66),
        accent: rgb(0.42, 0.72, 0.92),
        separator: rgb(0.32, 0.38, 0.48),
        danger: rgb(0.95, 0.40, 0.42),
        success: rgb(0.42, 0.78, 0.62),
        warning: rgb(0.94, 0.74, 0.32)
    )

    private static let emberDusk = ThemePalette(
        background: rgb(0.14, 0.10, 0.14),
        sidebarBackground: rgb(0.18, 0.12, 0.16),
        workbenchChrome: rgb(0.11, 0.08, 0.11),
        editorCanvas: rgb(0.20, 0.14, 0.18),
        surface: rgb(0.22, 0.16, 0.20),
        surfaceElevated: rgb(0.26, 0.19, 0.24),
        selectionPill: rgb(0.30, 0.22, 0.28),
        borderSubtle: rgb(0.38, 0.28, 0.34),
        textPrimary: rgb(0.96, 0.92, 0.94),
        textSecondary: rgb(0.70, 0.62, 0.66),
        textTertiary: rgb(0.54, 0.46, 0.50),
        accent: rgb(0.95, 0.52, 0.28),
        separator: rgb(0.34, 0.26, 0.30),
        danger: rgb(0.96, 0.38, 0.40),
        success: rgb(0.48, 0.72, 0.48),
        warning: rgb(0.96, 0.72, 0.32)
    )

    private static func rgb(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat) -> Color {
        Color(red: r, green: g, blue: b)
    }
}
