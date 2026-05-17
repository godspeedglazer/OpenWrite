import SwiftUI

/// LM Studio connection and model configuration (Settings window and sheet).
struct AISettingsView: View {
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @EnvironmentObject private var vaultStore: VaultStore

    @State private var baseURLString: String = LMStudioConfig.default.baseURL.absoluteString

    var body: some View {
        Form {
            Section {
                TextField("Server URL", text: $baseURLString)
                    .textFieldStyle(.roundedBorder)
                    .onSubmit { commitBaseURL() }

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
            } header: {
                Text("LM Studio")
            } footer: {
                Text("OpenAI-compatible endpoint on this Mac. Load models in LM Studio before chatting.")
            }

            Section("Status") {
                LabeledContent("Connection", value: aiServices.lmStatus)
                LabeledContent("Activity", value: aiServices.activityState.shortLabel)
                LabeledContent("Ingestion", value: aiServices.ingestionHealth.health.statusLabel)
                LabeledContent("Indexed chunks", value: "\(aiServices.indexedChunkCount)")

                if let progress = aiServices.ingestionHealth.health.progressSummary {
                    LabeledContent("Progress", value: progress)
                }

                if aiServices.isIndexing || aiServices.activityState == .indexing {
                    HStack(spacing: 8) {
                        ProgressView(value: aiServices.ingestionHealth.health.progressFraction)
                            .controlSize(.small)
                        Text("Indexing vault…")
                            .foregroundStyle(.secondary)
                    }
                }

                if let error = aiServices.ingestionHealth.health.lastError, !error.isEmpty {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.orange)
                }

                Button("Check connection") {
                    commitBaseURL()
                    Task { await aiServices.checkConnection() }
                }
                .disabled(aiServices.activityState == .connecting)

                Button("Rebuild index") {
                    Task { await aiServices.reindex(documents: vaultStore.documents) }
                }
                .disabled(aiServices.isIndexing)

                if aiServices.isIndexing {
                    Button("Cancel indexing", role: .destructive) {
                        aiServices.cancelIndexing()
                    }
                }
            }
        }
        .formStyle(.grouped)
        .padding()
        .onAppear {
            baseURLString = aiServices.lmConfig.baseURL.absoluteString
        }
    }

    private func commitBaseURL() {
        let trimmed = baseURLString.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: trimmed), !trimmed.isEmpty else { return }
        var config = aiServices.lmConfig
        config.baseURL = url
        aiServices.applyConfig(config)
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
}

#Preview {
    AISettingsView()
        .environmentObject(OpenWriteAIServices())
        .environmentObject(VaultStore.preview)
        .frame(width: 440, height: 420)
}
