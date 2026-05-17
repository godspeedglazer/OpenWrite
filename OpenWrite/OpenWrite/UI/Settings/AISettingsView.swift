import SwiftUI

/// LM Studio connection and model configuration (Settings window and sheet).
struct AISettingsView: View {
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @EnvironmentObject private var vaultStore: VaultStore

    @State private var baseURLString: String = LMStudioConfig.default.baseURL.absoluteString
    @State private var useCustomEmbeddingID = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing5) {
            OWSettingsSection(title: "LM Studio", footer: lmStudioFooter) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
                        Text("Server URL")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                        OWThemedTextField(placeholder: "http://127.0.0.1:1234", text: $baseURLString) {
                            commitBaseURL()
                        }
                    }

                    modelRoleRow(
                        title: "Chat model",
                        selection: chatModelBinding,
                        placeholder: "local-model"
                    )

                    embeddingModelSection
                }
            }

            OWSettingsSection(title: "Status") {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                    OWSettingsLabeledRow(label: "Connection", value: aiServices.lmStatus)
                    OWSettingsLabeledRow(label: "Activity", value: aiServices.activityState.shortLabel)
                    OWSettingsLabeledRow(label: "Ingestion", value: aiServices.ingestionHealth.health.statusLabel)
                    OWSettingsLabeledRow(label: "Indexed chunks", value: "\(aiServices.indexedChunkCount)")
                    OWSettingsLabeledRow(label: "Embedding", value: aiServices.lmConfig.embeddingModelDisplay)

                    if let progress = aiServices.ingestionHealth.health.progressSummary {
                        OWSettingsLabeledRow(label: "Progress", value: progress)
                    }

                    if aiServices.isIndexing || aiServices.activityState == .indexing {
                        HStack(spacing: DesignTokens.Spacing.spacing2) {
                            ProgressView(value: aiServices.ingestionHealth.health.progressFraction)
                                .controlSize(.small)
                                .tint(DesignTokens.Color.accent)
                            Text("Indexing vault…")
                                .font(DesignTokens.Typography.caption)
                                .foregroundStyle(DesignTokens.Color.textSecondary)
                        }
                    }

                    if let error = aiServices.ingestionHealth.health.lastError, !error.isEmpty {
                        Text(error)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.warning)
                    }

                    HStack(spacing: DesignTokens.Spacing.spacing2) {
                        Button("Check connection") {
                            commitBaseURL()
                            Task { await aiServices.checkConnection() }
                        }
                        .buttonStyle(OWSecondaryRectButtonStyle())
                        .disabled(aiServices.activityState == .connecting)

                        Button("Rebuild index") {
                            commitBaseURL()
                            Task { await aiServices.reindex(documents: vaultStore.documents) }
                        }
                        .buttonStyle(OWSecondaryRectButtonStyle())
                        .disabled(aiServices.isIndexing || vaultStore.documents.isEmpty)

                        if aiServices.isIndexing {
                            Button("Cancel indexing") {
                                aiServices.cancelIndexing()
                            }
                            .font(DesignTokens.Typography.captionEmphasis)
                            .foregroundStyle(DesignTokens.Color.danger)
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
            Text("Embedding model")
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textTertiary)

            if aiServices.availableModels.isEmpty {
                if useCustomEmbeddingID {
                    OWThemedTextField(placeholder: "Model id", text: embeddingModelBinding)
                    Button("Use recommended presets") {
                        useCustomEmbeddingID = false
                        aiServices.updateEmbeddingModel(EmbeddingModelPreset.defaultPreset.rawValue)
                    }
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.accent)
                    .buttonStyle(.plain)
                } else {
                    OWThemedDropdown(
                        accessibilityLabel: "Embedding preset",
                        selection: offlineEmbeddingPresetBinding,
                        options: Array(EmbeddingModelPreset.allCases),
                        optionTitle: \.menuTitle,
                        minWidth: 200
                    )
                    Button("Custom model id…") { useCustomEmbeddingID = true }
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.accent)
                        .buttonStyle(.plain)
                }
            } else {
                embeddingModelDropdown
            }

            Text(embeddingHelp)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var embeddingModelDropdown: some View {
        let options = embeddingModelOptions
        return OWThemedDropdown(
            accessibilityLabel: "Embedding model",
            selection: embeddingModelBinding,
            options: options,
            optionTitle: { $0.isEmpty ? "Same as chat model" : $0 },
            minWidth: 220
        )
    }

    private var embeddingModelOptions: [String] {
        var ids: [String] = [""]
        ids.append(contentsOf: EmbeddingModelPreset.allCases.map(\.rawValue))
        for model in aiServices.availableModels where !ids.contains(model.id) {
            if !EmbeddingModelPreset.allCases.map(\.rawValue).contains(model.id) {
                ids.append(model.id)
            }
        }
        return ids
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
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
            Text(title)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textTertiary)
            if aiServices.availableModels.isEmpty {
                OWThemedTextField(placeholder: placeholder, text: selection)
            } else {
                OWThemedDropdown(
                    accessibilityLabel: title,
                    selection: selection,
                    options: aiServices.availableModels.map(\.id),
                    optionTitle: { $0 },
                    minWidth: 220
                )
            }
        }
    }
}

#Preview {
    AISettingsView()
        .environmentObject(OpenWriteAIServices())
        .environmentObject(VaultStore.preview)
        .padding()
        .frame(width: 440, height: 520)
        .background(DesignTokens.Color.background)
}
