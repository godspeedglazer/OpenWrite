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

    var body: some View {
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
        .navigationTitle("OpenWrite")
        .sheet(isPresented: $showNewPageSheet) {
            newPageSheet
        }
        .sheet(isPresented: $showCreateDatabaseSheet) {
            CreateDatabaseSheet(workbench: workbench, isPresented: $showCreateDatabaseSheet)
                .environmentObject(vaultStore)
        }
        .sheet(isPresented: $showAISettings) {
            NavigationStack {
                OpenWriteSettingsView()
                    .navigationTitle("Settings")
                    .toolbar {
                        ToolbarItem(placement: .confirmationAction) {
                            Button("Done") { showAISettings = false }
                        }
                    }
            }
            .environment(themeManager)
            .openWritePalette(themeManager.palette)
            .preferredColorScheme(themeManager.selectedTheme.prefersDarkAppearance ? .dark : .light)
            .id(themeManager.selectedTheme)
            .frame(minWidth: 480, minHeight: 520)
        }
        .background(DesignTokens.Color.background)
        .task {
            await aiServices.reindex(documents: vaultStore.documents)
        }
        .onChange(of: vaultStore.documents) { _, documents in
            backlinkIndex = BacklinkIndex.build(from: documents)
            Task { await aiServices.reindex(documents: documents) }
        }
        .onAppear {
            backlinkIndex = BacklinkIndex.build(from: vaultStore.documents)
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
