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
        let _ = themeManager.revision
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
                .environment(themeManager)
                .environmentObject(vaultStore)
                .openWriteThemeAppearance()
                .openWriteSheetPresentationChrome()
        }
        .sheet(isPresented: $showCreateDatabaseSheet) {
            CreateDatabaseSheet(workbench: workbench, isPresented: $showCreateDatabaseSheet)
                .environmentObject(vaultStore)
                .openWriteThemeAppearance()
                .openWriteSheetPresentationChrome()
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
        .id(themeManager.revision)
        .task {
            _ = try? VaultLocationPreferences.ensureDefaultVaultLayout()
            await aiServices.startFilesystemIngestionWatch()
            markdownVaultWatcher.start {
                scheduleDebouncedReindex()
            }
            await aiServices.prepareVaultIndex(documents: vaultStore.documentsInActiveVault)
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
        let signature = OpenWriteAIServices.vaultContentSignature(
            documents: vaultStore.documentsInActiveVault
        )
        if aiServices.shouldSkipDebouncedReindex(for: signature) {
            return
        }
        reindexDebounceTask?.cancel()
        reindexDebounceTask = Task {
            try? await Task.sleep(nanoseconds: 2_000_000_000)
            guard !Task.isCancelled else { return }
            let documents = vaultStore.documentsInActiveVault
            if aiServices.indexedChunkCount > 0 {
                await aiServices.reindexChangedDocuments(in: documents)
            } else {
                await aiServices.reindex(documents: documents)
            }
        }
    }

    private var newPageSheet: some View {
        OWSettingsSheet(
            title: "Create page",
            dismissButtonTitle: "Cancel",
            dismissButtonUsesSecondaryStyle: true,
            onDone: { showNewPageSheet = false }
        ) {
            OpenWriteThemedScrollView(canvasColor: DesignTokens.Color.background) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing5) {
                    StructureTemplatePicker { newID in
                        vaultStore.selectedDocumentID = newID
                        showNewPageSheet = false
                    }

                    Rectangle()
                        .fill(DesignTokens.Color.separator)
                        .frame(height: DesignTokens.Layout.borderWidth)

                    TypePickerView(documentID: nil, mode: .create) { newID in
                        vaultStore.selectedDocumentID = newID
                        showNewPageSheet = false
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.Spacing.spacing5)
                .padding(.vertical, DesignTokens.Spacing.spacing4)
            }
            .background(DesignTokens.Color.background)
        }
        .frame(minWidth: 440, minHeight: 480)
    }
}

#Preview {
    ContentView()
        .environment(ThemeManager.shared)
        .environmentObject(VaultStore.preview)
        .environmentObject(OpenWriteAIServices())
        .environmentObject(InMemoryPastWritesService())
}
