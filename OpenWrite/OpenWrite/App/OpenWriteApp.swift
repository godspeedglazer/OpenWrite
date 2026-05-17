import SwiftUI

@main
struct OpenWriteApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    @StateObject private var vaultStore = VaultStore()
    @StateObject private var aiServices = OpenWriteAIServices()
    @StateObject private var pastWrites = InMemoryPastWritesService()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vaultStore)
                .environmentObject(aiServices)
                .environmentObject(pastWrites)
        }
        .defaultSize(width: 1280, height: 760)

        Settings {
            AISettingsView()
                .environmentObject(vaultStore)
                .environmentObject(aiServices)
        }
    }
}
