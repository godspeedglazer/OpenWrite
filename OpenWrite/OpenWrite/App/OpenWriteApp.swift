import SwiftUI

@main
struct OpenWriteApp: App {
    @StateObject private var vaultStore = VaultStore()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(vaultStore)
        }
        .defaultSize(width: 1100, height: 720)
    }
}
