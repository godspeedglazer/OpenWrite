import SwiftUI

// MARK: - Environment

private struct OpenWritePaletteKey: EnvironmentKey {
    static let defaultValue = ThemePalette.palette(for: .openWriteLight)
}

extension EnvironmentValues {
    /// Active semantic palette for views that read colors directly.
    var openWritePalette: ThemePalette {
        get { self[OpenWritePaletteKey.self] }
        set { self[OpenWritePaletteKey.self] = newValue }
    }
}

extension View {
    func openWritePalette(_ palette: ThemePalette) -> some View {
        environment(\.openWritePalette, palette)
    }

    /// Applies palette + system chrome from `ThemeManager` without resetting view identity.
    func openWriteThemeAppearance() -> some View {
        modifier(OpenWriteThemeAppearanceModifier())
    }
}

private struct OpenWriteThemeAppearanceModifier: ViewModifier {
    @Environment(ThemeManager.self) private var themeManager

    func body(content: Content) -> some View {
        // Read `selectedTheme` so @Observable invalidates this subtree on cycle/pick.
        let theme = themeManager.selectedTheme
        let palette = themeManager.palette
        return content
            .environment(\.openWritePalette, palette)
            .preferredColorScheme(theme.prefersDarkAppearance ? .dark : .light)
            .tint(palette.accent)
    }
}

// MARK: - Manager

@Observable
final class ThemeManager {
    static let storageKey = "com.openwrite.selectedThemeID"
    static let shared = ThemeManager()

    private(set) var selectedTheme: ThemeID {
        didSet {
            guard selectedTheme != oldValue else { return }
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.storageKey)
        }
    }

    var palette: ThemePalette {
        ThemePalette.palette(for: selectedTheme)
    }

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let restored = ThemeID.resolved(fromPersistedRawValue: raw) {
            selectedTheme = restored
        } else {
            selectedTheme = .openWriteLight
        }
    }

    func select(_ theme: ThemeID) {
        selectedTheme = theme
        OWWindowChrome.applyToAllWindows()
    }

    /// Cycles through all themes — used by the sidebar quick toggle.
    func selectNext() {
        let all = ThemeID.allCases
        guard let index = all.firstIndex(of: selectedTheme) else {
            select(all[0])
            return
        }
        select(all[(index + 1) % all.count])
    }
}
