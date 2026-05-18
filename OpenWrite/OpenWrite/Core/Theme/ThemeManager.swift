import SwiftUI

extension Notification.Name {
    /// Posted after `ThemeManager.select` — AppKit scroll hosts and window chrome listen for this.
    static let openWriteThemeDidChange = Notification.Name("com.openwrite.themeDidChange")
}

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

    /// Bumps on every theme change so SwiftUI can `.id(revision)` AppKit bridges.
    private(set) var revision: UInt = 0

    private(set) var selectedTheme: ThemeID {
        didSet {
            guard selectedTheme != oldValue else { return }
            UserDefaults.standard.set(selectedTheme.rawValue, forKey: Self.storageKey)
        }
    }

    var palette: ThemePalette {
        ThemePalette.palette(for: selectedTheme)
    }

    private var pendingTheme: ThemeID?
    private var applyTask: Task<Void, Never>?

    private init() {
        if let raw = UserDefaults.standard.string(forKey: Self.storageKey),
           let restored = ThemeID.resolved(fromPersistedRawValue: raw) {
            selectedTheme = restored
        } else {
            selectedTheme = .openWriteLight
        }
    }

    /// Commits after 200ms of quiet — one `applyToAllWindows` per settled change.
    func select(_ theme: ThemeID) {
        let effective = pendingTheme ?? selectedTheme
        guard theme != effective else { return }
        pendingTheme = theme
        applyTask?.cancel()
        applyTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 200_000_000)
            guard !Task.isCancelled, let pending = pendingTheme else { return }
            commit(pending)
        }
    }

    /// Cycles through all themes — used by the sidebar quick toggle.
    func selectNext() {
        let current = pendingTheme ?? selectedTheme
        let all = ThemeID.allCases
        guard let index = all.firstIndex(of: current) else {
            select(all[0])
            return
        }
        select(all[(index + 1) % all.count])
    }

    private func commit(_ theme: ThemeID) {
        pendingTheme = nil
        applyTask = nil
        guard theme != selectedTheme else { return }
        selectedTheme = theme
        revision &+= 1
        NotificationCenter.default.post(name: .openWriteThemeDidChange, object: nil)
    }
}
