import SwiftUI

struct ContentView: View {
    @Environment(ThemeManager.self) private var themeManager
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @EnvironmentObject private var pastWrites: InMemoryPastWritesService
    @StateObject private var workbench = WorkbenchState()
    @State private var showNewPageSheet = false
    @State private var showAISettings = false
    @State private var showCreateDatabaseSheet = false
    @State private var backlinkIndex = BacklinkIndex()
    @StateObject private var markdownVaultWatcher = VaultMarkdownWatcher()

    var body: some View {
        let _ = themeManager.selectedTheme
        AnytypeShellView(
            workbench: workbench,
            backlinkIndex: backlinkIndex,
            showNewPageSheet: $showNewPageSheet,
            showAISettings: $showAISettings,
            showCreateDatabaseSheet: $showCreateDatabaseSheet
        )
        .environmentObject(workbench)
        .frame(
            minWidth: DesignTokens.Layout.windowMinWidth,
            minHeight: DesignTokens.Layout.windowMinHeight
        )
        .openWriteWindowChrome()
        .sheet(isPresented: $showNewPageSheet) {
            newPageSheet
        }
        .sheet(isPresented: $showCreateDatabaseSheet) {
            CreateDatabaseSheet(workbench: workbench, isPresented: $showCreateDatabaseSheet)
                .environmentObject(vaultStore)
        }
        .sheet(isPresented: $showAISettings) {
            OWSettingsSheet(title: "Settings", onDone: { showAISettings = false }) {
                OpenWriteSettingsView()
            }
            .environment(themeManager)
            .environmentObject(vaultStore)
            .environmentObject(aiServices)
            .openWriteThemeAppearance()
            .frame(minWidth: 480, minHeight: 520)
        }
        .background(DesignTokens.Color.background)
        .task {
            _ = try? VaultLocationPreferences.ensureDefaultVaultLayout()
            await aiServices.startFilesystemIngestionWatch()
            markdownVaultWatcher.start {
                Task { await aiServices.reindex(documents: vaultStore.documents) }
            }
            await aiServices.reindex(documents: vaultStore.documents)
        }
        .onDisappear {
            markdownVaultWatcher.stop()
        }
        .onChange(of: vaultStore.documents) { _, _ in
            rebuildBacklinkIndex()
        }
        .onChange(of: vaultStore.activeVaultID) { _, newVaultID in
            workbench.applyVaultContext(newVaultID)
            rebuildBacklinkIndex()
        }
        .onAppear {
            workbench.applyVaultContext(vaultStore.activeVaultID)
            rebuildBacklinkIndex()
        }
    }

    private func rebuildBacklinkIndex() {
        let scoped = vaultStore.documentsInActiveVault
        backlinkIndex = BacklinkIndex.build(from: scoped)
        Task { await aiServices.reindex(documents: vaultStore.documents) }
    }

    private var newPageSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing5) {
                Text("Create page")
                    .font(DesignTokens.Typography.heading2)

                StructureTemplatePicker { newID in
                    vaultStore.selectedDocumentID = newID
                    showNewPageSheet = false
                }

                Divider()

                TypePickerView(documentID: nil, mode: .create) { newID in
                    vaultStore.selectedDocumentID = newID
                    showNewPageSheet = false
                }

                HStack {
                    Spacer()
                    Button("Cancel") { showNewPageSheet = false }
                }
            }
            .padding(DesignTokens.Spacing.spacing6)
        }
        .frame(minWidth: 400, minHeight: 420)
    }
}

#Preview {
    ContentView()
        .environment(ThemeManager.shared)
        .environmentObject(VaultStore.preview)
        .environmentObject(OpenWriteAIServices())
        .environmentObject(InMemoryPastWritesService())
}
