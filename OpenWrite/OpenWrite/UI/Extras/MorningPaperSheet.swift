import SwiftUI

struct MorningPaperSheet: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var aiServices: OpenWriteAIServices

    let onDismiss: () -> Void

    @State private var template: MorningPaperTemplate = .brief
    @State private var slots: MorningPaperSlots?
    @State private var isLoading = true
    @State private var statusMessage: String?

    var body: some View {
        OWSettingsSheet(
            title: "Morning Paper",
            dismissButtonTitle: "Close",
            dismissButtonUsesSecondaryStyle: true,
            onDone: onDismiss
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing4) {
                Text("Print-style layouts filled from your indexed notes. Hidden under Extras — not part of the daily writing chrome.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)

                Picker("Template", selection: $template) {
                    ForEach(MorningPaperTemplate.allCases) { item in
                        Text(item.displayName).tag(item)
                    }
                }
                .pickerStyle(.segmented)

                if isLoading {
                    ProgressView("Gathering local stories…")
                } else if let preview = previewBlocks {
                    ScrollView {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                            ForEach(preview.filter { $0.kind != .property }) { block in
                                Text(blockPreview(block))
                                    .font(previewFont(for: block.kind))
                                    .foregroundStyle(DesignTokens.Color.textPrimary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                        .padding(DesignTokens.Spacing.spacing3)
                    }
                    .frame(minHeight: 220, maxHeight: 320)
                    .background(DesignTokens.Color.surfaceElevated, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))

                    HStack(spacing: DesignTokens.Spacing.spacing2) {
                        Button("Refresh") {
                            Task { await reloadSlots() }
                        }
                        .buttonStyle(.bordered)

                        Button("Insert as new page") {
                            insertPage()
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }

                if let statusMessage {
                    Text(statusMessage)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }

                Text(RefineAvailability.indexOfflineNotice)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.spacing4)
            .padding(.vertical, DesignTokens.Spacing.spacing3)
        }
        .frame(minWidth: 520, minHeight: 480)
        .task { await reloadSlots() }
        .onChange(of: template) { _, _ in
            statusMessage = nil
        }
    }

    private var previewBlocks: [NoteBlock]? {
        guard let slots else { return nil }
        return MorningPaperGenerator.blocks(template: template, slots: slots)
    }

    private func reloadSlots() async {
        isLoading = true
        let root = VaultLocationPreferences.resolvedVaultRootURL()
        let gathered = await MorningPaperGenerator.gatherSlots(
            retrieval: aiServices.retrieval,
            vaultRoot: root,
            documents: vaultStore.documentsInActiveVault
        )
        await MainActor.run {
            slots = gathered
            isLoading = false
        }
    }

    private func insertPage() {
        guard let slots else { return }
        let blocks = MorningPaperGenerator.blocks(template: template, slots: slots)
        let title = MorningPaperGenerator.pageTitle(template: template, slots: slots)
        var doc = vaultStore.createDocument(pageType: .note, title: title, fromTemplate: false)
        doc.rootBlocks = blocks
        vaultStore.updateDocument(doc)
        vaultStore.selectedDocumentID = doc.id
        statusMessage = "Created “\(title)” in your library."
        onDismiss()
    }

    private func blockPreview(_ block: NoteBlock) -> String {
        switch block.kind {
        case .heading1: return "# \(block.text)"
        case .heading2: return "## \(block.text)"
        case .bullet: return "• \(block.text)"
        case .quote: return "“\(block.text)”"
        case .todo: return block.isChecked ? "☑ \(block.text)" : "☐ \(block.text)"
        case .callout: return block.text
        default: return block.text
        }
    }

    private func previewFont(for kind: NoteBlock.Kind) -> Font {
        switch kind {
        case .heading1: return DesignTokens.Typography.heading1
        case .heading2: return DesignTokens.Typography.bodyEmphasis
        default: return DesignTokens.Typography.body
        }
    }
}
