import SwiftUI

/// LM Studio connection and model configuration (Settings window and sheet).
struct AISettingsView: View {
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @EnvironmentObject private var vaultStore: VaultStore

    @State private var baseURLString: String = LMStudioConfig.default.baseURL.absoluteString
    @State private var useCustomEmbeddingID = false

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

                embeddingModelSection
            } header: {
                Text("LM Studio")
            } footer: {
                Text(lmStudioFooter)
            }

            Section("Status") {
                LabeledContent("Connection", value: aiServices.lmStatus)
                LabeledContent("Activity", value: aiServices.activityState.shortLabel)
                LabeledContent("Ingestion", value: aiServices.ingestionHealth.health.statusLabel)
                LabeledContent("Indexed chunks", value: "\(aiServices.indexedChunkCount)")
                LabeledContent("Embedding", value: aiServices.lmConfig.embeddingModelDisplay)

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
                    commitBaseURL()
                    Task { await aiServices.reindex(documents: vaultStore.documents) }
                }
                .disabled(aiServices.isIndexing || vaultStore.documents.isEmpty)

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
            let id = aiServices.lmConfig.embeddingModel
            useCustomEmbeddingID = !EmbeddingModelPreset.allCases.contains { $0.rawValue == id }
        }
    }

    private var lmStudioFooter: String {
        """
        OpenAI-compatible endpoint on this Mac. Load chat and embedding models in LM Studio before chatting or rebuilding the index. \
        Recommended embedding: \(EmbeddingModelPreset.defaultPreset.menuTitle) (\(LMStudioConfig.defaultEmbeddingModelID)) — download the GGUF in LM Studio; OpenWrite does not bundle model weights. \
        After changing the embedding model, rebuild the index so vectors match.
        """
    }

    @ViewBuilder
    private var embeddingModelSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Embedding model")
                .font(.caption)
                .foregroundStyle(.secondary)

            if aiServices.availableModels.isEmpty {
                if useCustomEmbeddingID {
                    TextField("Model id", text: embeddingModelBinding)
                        .textFieldStyle(.roundedBorder)
                    Button("Use recommended presets") {
                        useCustomEmbeddingID = false
                        aiServices.updateEmbeddingModel(EmbeddingModelPreset.defaultPreset.rawValue)
                    }
                    .font(.caption)
                } else {
                    Picker("Preset", selection: offlineEmbeddingPresetBinding) {
                        ForEach(EmbeddingModelPreset.allCases) { preset in
                            Text(preset.menuTitle).tag(preset)
                        }
                    }
                    .labelsHidden()
                    Button("Custom model id…") { useCustomEmbeddingID = true }
                        .font(.caption)
                }
            } else {
                Picker("Embedding model", selection: embeddingModelBinding) {
                    Text("Same as chat model").tag("")
                    ForEach(EmbeddingModelPreset.allCases, id: \.rawValue) { preset in
                        Text(preset.menuTitle).tag(preset.rawValue)
                    }
                    ForEach(aiServices.availableModels) { model in
                        if !EmbeddingModelPreset.allCases.map(\.rawValue).contains(model.id) {
                            Text(model.id).tag(model.id)
                        }
                    }
                }
                .labelsHidden()
            }

            Text(embeddingHelp)
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var embeddingHelp: String {
        "Vector search uses this model at /v1/embeddings. Default: \(LMStudioConfig.defaultEmbeddingModelID)."
    }

    private var offlineEmbeddingPresetBinding: Binding<EmbeddingModelPreset> {
        Binding(
            get: {
                let id = aiServices.lmConfig.embeddingModel
                return EmbeddingModelPreset.allCases.first { $0.rawValue == id } ?? .defaultPreset
            },
            set: { aiServices.updateEmbeddingModel($0.rawValue) }
        )
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
        .frame(width: 440, height: 520)
}
