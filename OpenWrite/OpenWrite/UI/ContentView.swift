import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @EnvironmentObject private var pastWrites: InMemoryPastWritesService
    @StateObject private var workbench = WorkbenchState()
    @State private var showNewPageSheet = false

    var body: some View {
        NavigationSplitView {
            sidebar
        } content: {
            editorColumn
        } detail: {
            if workbench.inspectorVisible {
                WorkbenchInspectorView(
                    workbench: workbench,
                    pastWrites: pastWrites
                )
            } else {
                Color.clear
                    .frame(width: 1)
            }
        }
        .navigationTitle("OpenWrite")
        .sheet(isPresented: $showNewPageSheet) {
            newPageSheet
        }
        .task {
            await aiServices.reindex(documents: vaultStore.documents)
        }
        .onChange(of: vaultStore.documents) { _, documents in
            Task { await aiServices.reindex(documents: documents) }
        }
    }

    private var sidebar: some View {
        List(selection: $vaultStore.selectedDocumentID) {
            Section {
                Button {
                    showNewPageSheet = true
                } label: {
                    Label("New typed page", systemImage: "plus.circle.fill")
                }
            }

            Section("Vault") {
                if vaultStore.documents.isEmpty {
                    Text("No notes yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vaultStore.documents) { doc in
                        Button {
                            vaultStore.selectedDocumentID = doc.id
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: doc.pageType.systemImage)
                                    .foregroundStyle(.secondary)
                                    .frame(width: 18)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(doc.displayTitle)
                                        .lineLimit(1)
                                    Text(doc.pageType.displayName)
                                        .font(.caption2)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(
                            vaultStore.selectedDocumentID == doc.id ? Color.primary : Color.secondary
                        )
                    }
                }
            }

            Section("LM Studio") {
                LabeledContent("Server", value: aiServices.lmConfig.baseURL.absoluteString)
                    .font(.caption)

                modelRoleRow(
                    title: "Chat model",
                    selection: chatModelBinding,
                    placeholder: "local-model"
                )

                modelRoleRow(
                    title: "Embedding model",
                    selection: embeddingModelBinding,
                    placeholder: "Same as chat model"
                )

                HStack {
                    Text("Activity")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(aiServices.activityState.shortLabel)
                        .font(.caption.weight(.medium))
                }

                Text(aiServices.lmStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                LabeledContent("Indexed chunks", value: "\(aiServices.indexedChunkCount)")

                if aiServices.isIndexing || aiServices.activityState == .indexing {
                    HStack(spacing: 8) {
                        ProgressView()
                            .controlSize(.small)
                        Text("Indexing vault…")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Button("Check connection") {
                    Task { await aiServices.checkConnection() }
                }
                .disabled(aiServices.activityState == .connecting)

                Button("Rebuild index") {
                    Task { await aiServices.reindex(documents: vaultStore.documents) }
                }
                .disabled(aiServices.isIndexing)
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 240)
    }

    private var chatModelBinding: Binding<String> {
        Binding(
            get: { aiServices.lmConfig.chatModel },
            set: { aiServices.updateChatModel($0) }
        )
    }

    private var embeddingModelBinding: Binding<String> {
        Binding(
            get: { aiServices.lmConfig.embeddingModel },
            set: { aiServices.updateEmbeddingModel($0) }
        )
    }

    @ViewBuilder
    private func modelRoleRow(title: String, selection: Binding<String>, placeholder: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            if aiServices.availableModels.isEmpty {
                TextField(placeholder, text: selection)
                    .textFieldStyle(.roundedBorder)
                    .font(.caption)
            } else {
                Picker(title, selection: selection) {
                    if title == "Embedding model" {
                        Text(placeholder).tag("")
                    }
                    ForEach(aiServices.availableModels) { model in
                        Text(model.id).tag(model.id)
                    }
                }
                .labelsHidden()
            }
        }
    }

    private var newPageSheet: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                Text("Create page")
                    .font(.title2.bold())

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
            .padding(24)
        }
        .frame(minWidth: 400, minHeight: 420)
    }

    @ViewBuilder
    private var editorColumn: some View {
        HStack(spacing: 0) {
            Group {
                if let doc = vaultStore.selectedDocument {
                    EditorView(documentID: doc.id)
                } else {
                    ContentUnavailableView(
                        "Select a note",
                        systemImage: "square.and.pencil",
                        description: Text("OpenWrite vault — encrypted local notes with NDL typed pages.")
                    )
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            inspectorToggle
        }
    }

    private var inspectorToggle: some View {
        VStack {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    workbench.inspectorVisible.toggle()
                }
            } label: {
                Image(systemName: workbench.inspectorVisible ? "sidebar.right" : "sidebar.left")
            }
            .buttonStyle(.borderless)
            .help(workbench.inspectorVisible ? "Hide inspector" : "Show inspector")
            Spacer()
        }
        .padding(.horizontal, 4)
    }
}

#Preview {
    ContentView()
        .environmentObject(VaultStore.preview)
        .environmentObject(OpenWriteAIServices())
        .environmentObject(InMemoryPastWritesService())
}
