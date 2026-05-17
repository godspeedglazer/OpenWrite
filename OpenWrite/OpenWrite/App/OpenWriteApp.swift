import SwiftUI

@main
struct OpenWriteApp: App {
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
    }
}
