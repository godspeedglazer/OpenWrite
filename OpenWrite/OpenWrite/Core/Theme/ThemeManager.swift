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
