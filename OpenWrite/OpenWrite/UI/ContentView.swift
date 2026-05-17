import SwiftUI

struct ContentView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @State private var lmConfig = LMStudioConfig.default
    @State private var lmStatus: String = "Not checked"

    var body: some View {
        NavigationSplitView {
            sidebar
        } detail: {
            detail
        }
        .navigationTitle("OpenWrite")
    }

    private var sidebar: some View {
        List(selection: $vaultStore.selectedDocumentID) {
            Section("Vault") {
                if vaultStore.documents.isEmpty {
                    Text("No notes yet")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(vaultStore.documents) { doc in
                        Button {
                            vaultStore.selectedDocumentID = doc.id
                        } label: {
                            Label(doc.title, systemImage: "doc.text")
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(
                            vaultStore.selectedDocumentID == doc.id ? Color.primary : Color.secondary
                        )
                    }
                }
            }

            Section("AI") {
                LabeledContent("LM Studio", value: lmConfig.baseURL.absoluteString)
                Text(lmStatus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Button("Check connection") {
                    Task { await checkLMStudio() }
                }
            }
        }
        .listStyle(.sidebar)
        .frame(minWidth: 220)
    }

    @ViewBuilder
    private var detail: some View {
        if let doc = vaultStore.selectedDocument {
            EditorView(document: doc)
        } else {
            ContentUnavailableView(
                "Select a note",
                systemImage: "square.and.pencil",
                description: Text("OpenWrite vault — encrypted local notes with NDL.")
            )
        }
    }

    private func checkLMStudio() async {
        lmStatus = "Checking…"
        let client = LMStudioClient(config: lmConfig)
        do {
            let ok = try await client.healthCheck()
            lmStatus = ok ? "Reachable" : "Unreachable"
        } catch {
            lmStatus = "Error: \(error.localizedDescription)"
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(VaultStore.preview)
}
