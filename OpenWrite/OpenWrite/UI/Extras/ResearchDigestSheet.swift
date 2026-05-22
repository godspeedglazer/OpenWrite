import SwiftUI

struct ResearchDigestSheet: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var aiServices: OpenWriteAIServices

    let onDismiss: () -> Void

    @State private var markdownFiles: [VaultMarkdownFile] = []
    @State private var selectedDocumentIDs: Set<UUID> = []
    @State private var selectedRelativePaths: Set<String> = []
    @State private var digestText: String = ""
    @State private var isGenerating = false
    @State private var statusMessage: String?

    var body: some View {
        OWSettingsSheet(
            title: "Research digest",
            dismissButtonTitle: "Close",
            dismissButtonUsesSecondaryStyle: true,
            onDone: onDismiss
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing4) {
                Text("NotebookLM-style brief across selected notes. Uses your Note Summarizer agent when LM Studio is connected; otherwise shows a local excerpt collage.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)

                selectionList

                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    Button(isGenerating ? "Generating…" : "Generate digest") {
                        Task { await generate() }
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isGenerating || selectionCount == 0)

                    Button("Insert as new page") {
                        insertDigestPage()
                    }
                    .buttonStyle(.bordered)
                    .disabled(digestText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }

                if isGenerating {
                    ProgressView()
                }

                TextEditor(text: $digestText)
                    .font(DesignTokens.Typography.body)
                    .frame(minHeight: 200, maxHeight: 280)
                    .scrollContentBackground(.hidden)
                    .padding(DesignTokens.Spacing.spacing2)
                    .background(DesignTokens.Color.surfaceElevated, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))

                if let statusMessage {
                    Text(statusMessage)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.spacing4)
            .padding(.vertical, DesignTokens.Spacing.spacing3)
        }
        .frame(minWidth: 560, minHeight: 520)
        .onAppear {
            markdownFiles = VaultMarkdownCatalog.scan(
                vaultRoot: VaultLocationPreferences.resolvedVaultRootURL()
            )
            selectedDocumentIDs = Set(vaultStore.documentsInActiveVault.prefix(3).map(\.id))
        }
    }

    private var selectionCount: Int {
        selectedDocumentIDs.count + selectedRelativePaths.count
    }

    @ViewBuilder
    private var selectionList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                Text("In-app pages")
                    .font(DesignTokens.Typography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                ForEach(vaultStore.documentsInActiveVault) { doc in
                    Toggle(isOn: bindingForDocument(doc.id)) {
                        Text(doc.title)
                            .font(DesignTokens.Typography.body)
                    }
                    .toggleStyle(.checkbox)
                }

                if !markdownFiles.isEmpty {
                    Text("On-disk markdown")
                        .font(DesignTokens.Typography.captionEmphasis)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .padding(.top, DesignTokens.Spacing.spacing2)
                    ForEach(markdownFiles, id: \.relativePath) { file in
                        Toggle(isOn: bindingForPath(file.relativePath)) {
                            Text(file.sourceFilename)
                                .font(DesignTokens.Typography.caption)
                        }
                        .toggleStyle(.checkbox)
                    }
                }
            }
        }
        .frame(maxHeight: 160)
    }

    private func bindingForDocument(_ id: UUID) -> Binding<Bool> {
        Binding(
            get: { selectedDocumentIDs.contains(id) },
            set: { on in
                if on { selectedDocumentIDs.insert(id) } else { selectedDocumentIDs.remove(id) }
            }
        )
    }

    private func bindingForPath(_ path: String) -> Binding<Bool> {
        Binding(
            get: { selectedRelativePaths.contains(path) },
            set: { on in
                if on { selectedRelativePaths.insert(path) } else { selectedRelativePaths.remove(path) }
            }
        )
    }

    private func generate() async {
        let sources = ResearchDigestBuilder.sources(
            from: vaultStore.documentsInActiveVault,
            markdownFiles: markdownFiles,
            selectedDocumentIDs: selectedDocumentIDs,
            selectedRelativePaths: selectedRelativePaths
        )
        guard !sources.isEmpty else { return }

        await MainActor.run {
            isGenerating = true
            statusMessage = nil
        }

        if aiServices.lmConnectionState != .connected {
            await MainActor.run {
                digestText = offlineCollage(sources: sources)
                statusMessage = RefineAvailability.refineRequiresChatModel
                isGenerating = false
            }
            return
        }

        let query = ResearchDigestBuilder.query(sources: sources)
        let agent = AgentRegistry.noteSummarizer
        do {
            let answer = try await aiServices.rag.answer(query: query, agent: agent, attachments: [], history: [])
            await MainActor.run {
                digestText = answer.text
                statusMessage = "Digest generated from \(sources.count) source(s)."
                isGenerating = false
            }
        } catch {
            await MainActor.run {
                digestText = offlineCollage(sources: sources)
                statusMessage = error.localizedDescription
                isGenerating = false
            }
        }
    }

    private func offlineCollage(sources: [ResearchDigestSource]) -> String {
        var lines = ["## Summary", "Local excerpt collage (connect LM Studio for a synthesized digest).", "", "## Key points"]
        for source in sources.prefix(8) {
            let excerpt = source.excerpt.prefix(280)
            lines.append("- **\(source.title)** (\(source.sourceLabel)): \(excerpt)…")
        }
        return lines.joined(separator: "\n")
    }

    private func insertDigestPage() {
        let title = "Research digest · \(formattedDate())"
        let blocks = ResearchDigestBuilder.digestBlocks(title: title, body: digestText)
        var doc = vaultStore.createDocument(pageType: .note, title: title, fromTemplate: false)
        doc.rootBlocks = blocks
        vaultStore.updateDocument(doc)
        vaultStore.selectedDocumentID = doc.id
        onDismiss()
    }

    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }
}
