import SwiftUI

@main
struct OpenWriteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @State private var themeManager = ThemeManager.shared
    @StateObject private var vaultStore = VaultStore()
    @StateObject private var aiServices = OpenWriteAIServices()
    @StateObject private var pastWrites = InMemoryPastWritesService()

    var body: some Scene {
        WindowGroup {
            LaunchRootView {
                ContentView()
            }
            .environment(themeManager)
            .openWritePalette(themeManager.palette)
            .preferredColorScheme(themeManager.selectedTheme.prefersDarkAppearance ? .dark : .light)
            .id(themeManager.selectedTheme)
            .environmentObject(vaultStore)
            .environmentObject(aiServices)
            .environmentObject(pastWrites)
        }
        .defaultSize(
            width: DesignTokens.Layout.windowDefaultWidth,
            height: DesignTokens.Layout.windowDefaultHeight
        )

        Settings {
            OpenWriteSettingsView()
                .environment(themeManager)
                .openWritePalette(themeManager.palette)
                .preferredColorScheme(themeManager.selectedTheme.prefersDarkAppearance ? .dark : .light)
                .id(themeManager.selectedTheme)
                .environmentObject(vaultStore)
                .environmentObject(aiServices)
        }
    }
}
