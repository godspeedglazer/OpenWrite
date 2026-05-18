import SwiftUI

private struct OpenWriteRootView: View {
    @Environment(ThemeManager.self) private var themeManager
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @EnvironmentObject private var pastWrites: InMemoryPastWritesService

    var body: some View {
        LaunchRootView {
            ContentView()
        }
        .openWriteThemeAppearance()
    }
}

private struct OpenWriteSettingsRootView: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        OpenWriteSettingsView()
            .openWriteThemeAppearance()
    }
}

@main
struct OpenWriteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var vaultStore = VaultStore()
    @StateObject private var aiServices = OpenWriteAIServices()
    @StateObject private var pastWrites = InMemoryPastWritesService()

    var body: some Scene {
        WindowGroup {
            OpenWriteRootView()
                .environment(ThemeManager.shared)
                .environmentObject(vaultStore)
                .environmentObject(aiServices)
                .environmentObject(pastWrites)
        }
        .windowToolbarStyle(.unifiedCompact(showsTitle: false))
        .defaultSize(
            width: DesignTokens.Layout.windowDefaultWidth,
            height: DesignTokens.Layout.windowDefaultHeight
        )

        Settings {
            OpenWriteSettingsRootView()
                .environment(ThemeManager.shared)
                .environmentObject(vaultStore)
                .environmentObject(aiServices)
        }
        .commands {
            CommandGroup(replacing: .undoRedo) {
                Button("Undo") {
                    NSApp.sendAction(Selector(("undo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: .command)

                Button("Redo") {
                    NSApp.sendAction(Selector(("redo:")), to: nil, from: nil)
                }
                .keyboardShortcut("z", modifiers: [.command, .shift])
            }
        }
    }
}
