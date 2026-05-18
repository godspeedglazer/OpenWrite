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
    @State private var reindexDebounceTask: Task<Void, Never>?

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
        .background(DesignTokens.Color.shellChrome)
        .task {
            _ = try? VaultLocationPreferences.ensureDefaultVaultLayout()
            await aiServices.startFilesystemIngestionWatch()
            markdownVaultWatcher.start {
                scheduleDebouncedReindex()
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
        .onChange(of: activeVaultDocumentSignature) { _, _ in
            rebuildBacklinkIndex()
        }
        .onAppear {
            workbench.applyVaultContext(vaultStore.activeVaultID)
            rebuildBacklinkIndex()
        }
    }

    /// Changes when the active vault or its member pages change (vault switch does not mutate `documents`).
    private var activeVaultDocumentSignature: Int {
        var hasher = Hasher()
        hasher.combine(vaultStore.activeVaultID)
        for document in vaultStore.documentsInActiveVault {
            hasher.combine(document.id)
            hasher.combine(document.updatedAt)
        }
        return hasher.finalize()
    }

    private func rebuildBacklinkIndex() {
        let scoped = vaultStore.documentsInActiveVault
        backlinkIndex = BacklinkIndex.build(from: scoped)
        scheduleDebouncedReindex()
    }

    private func scheduleDebouncedReindex() {
        reindexDebounceTask?.cancel()
        reindexDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 750_000_000)
            guard !Task.isCancelled else { return }
            await aiServices.reindex(documents: vaultStore.documents)
        }
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
                        .openWriteFocusChrome(.themedKeyboard)
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
