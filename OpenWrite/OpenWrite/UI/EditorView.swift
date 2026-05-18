import SwiftUI

struct EditorView: View {
    @Environment(\.openWritePalette) private var palette
    @Environment(ThemeManager.self) private var themeManager
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var pastWrites: InMemoryPastWritesService
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @EnvironmentObject private var workbench: WorkbenchState

    let documentID: UUID
    @State private var editingBlocks: [NoteBlock] = []
    @State private var showProperties: Bool = false
    @State private var showTypePicker: Bool = false
    @State private var headerTitle: String = ""
    @State private var headerPageIcon: String = ""
    @State private var headerCoverStyle: CoverStyle?
    @State private var headerCoverImagePath: String?
    @State private var headerIconOffsetX: CGFloat = 0
    @State private var headerIconOffsetY: CGFloat = 0
    @State private var appliedEditorPresentation = false
    @StateObject private var inlineAssist = InlineAssistController()
    @StateObject private var blockFormatting = BlockFormattingState()
    @State private var isEditorPreviewMode = false
    @State private var blocksCommitTask: Task<Void, Never>?

    init(document: VaultDocument) {
        self.documentID = document.id
    }

    init(documentID: UUID) {
        self.documentID = documentID
    }

    private var document: VaultDocument? {
        vaultStore.documents.first { $0.id == documentID }
    }

    var body: some View {
        let _ = themeManager.revision
        Group {
            if let document {
                editorBody(document)
            } else {
                OWEmptyState(title: "Note missing", icon: .missingNote)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(DesignTokens.Color.background)
        .environment(\.blockFormatting, blockFormatting)
        .sheet(isPresented: $inlineAssist.showRefineResult) {
            refineResultSheet
        }
        .onAppear {
            syncFromDocument(document)
            syncHeaderFromDocument(document)
        }
        .onChange(of: documentID) { _, _ in
            appliedEditorPresentation = false
            if let doc = self.document {
                syncFromDocument(doc)
                syncHeaderFromDocument(doc)
            }
        }
        .onChange(of: document?.updatedAt) { _, _ in
            guard let doc = self.document else { return }
            let body = doc.rootBlocks.filter { $0.kind != .property }
            if body != editingBlocks {
                syncFromDocument(doc)
            }
        }
        .onDisappear {
            if let doc = document {
                flushPendingBlocksCommit(document: doc)
            }
        }
    }

    @ViewBuilder
    private func editorBody(_ document: VaultDocument) -> some View {
        VStack(spacing: 0) {
            if showTypePicker {
                editorTypePickerStrip(document)
            }

            editorScrollSurface(document)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .layoutPriority(1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func pageBanner(_ document: VaultDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            OWPageHeaderEditor(
                documentID: document.id,
                title: $headerTitle,
                pageIcon: $headerPageIcon,
                coverStyle: $headerCoverStyle,
                coverImagePath: $headerCoverImagePath,
                pageIconOffsetX: $headerIconOffsetX,
                pageIconOffsetY: $headerIconOffsetY
            ) {
                metadataRow(document)
            }

            if showProperties {
                OWRoundedRect(style: .elevated, padding: DesignTokens.Spacing.spacing2) {
                    PropertyInspectorView(documentID: document.id)
                }
                .openWriteEditorContentWidth()
                .openWriteEditorLeadingInset()
                .padding(.bottom, DesignTokens.Spacing.spacing2)
            }
        }
    }

    private func metadataRow(_ document: VaultDocument) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.spacing2) {
                Button {
                    showTypePicker.toggle()
                } label: {
                    OWObjectTypeChip(pageType: document.pageType)
                }
                .buttonStyle(.plain)
                .openWriteFocusChrome()
                .help(showTypePicker ? "Hide type picker" : "Change page type")

                OWMetadataChip(
                    label: "Updated",
                    icon: .clock,
                    value: document.updatedAt.formatted(.relative(presentation: .named))
                )

                if let status = nonEmptyProperty(document, key: .status) {
                    OWMetadataChip(label: status, icon: .statusDot)
                }

                if let tags = nonEmptyProperty(document, key: .tags) {
                    OWMetadataChip(label: tags, icon: .tag)
                }

                Button {
                    showProperties.toggle()
                } label: {
                    OWMetadataChip(
                        label: showProperties ? "Hide properties" : "Properties",
                        icon: .sliders
                    )
                }
                .buttonStyle(.plain)
            .openWriteFocusChrome()
            }
        }
        .padding(.bottom, DesignTokens.Layout.editorMetadataToToolbarSpacing)
    }

    private func editorTypePickerStrip(_ document: VaultDocument) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            TypePickerView(documentID: document.id, mode: .switchType, layout: .compact)

            if document.rootBlocks.filter({ $0.kind != .property }).isEmpty {
                welcomeBodyHint
            }
        }
        .openWriteEditorLeadingInset()
        .padding(.bottom, DesignTokens.Spacing.spacing1)
    }

    private var welcomeBodyHint: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            Text("This page is empty — pick a type above or start from the template below.")
                .font(OWTypography.caption)
                .foregroundStyle(DesignTokens.Color.textSecondary)

            ForEach(VaultDocument.welcomeSample.rootBlocks.filter { $0.kind != .property }.prefix(3)) { block in
                OWPreviewBlockRow(block: block)
            }

            Button("Apply welcome starter blocks") {
                guard let doc = document else { return }
                editingBlocks = VaultDocument.welcomeSample.rootBlocks.filter { $0.kind != .property }
                commitBlocks(document: doc, blocks: editingBlocks)
            }
            .buttonStyle(.plain)
            .openWriteFocusChrome()
            .font(OWTypography.captionEmphasis)
            .foregroundStyle(DesignTokens.Color.accent)
        }
        .openWriteEditorContentWidth()
    }

    private var blockFormattingBar: some View {
        OWBlockFormattingToolbar(
            formatting: blockFormatting,
            blockAttributes: focusedBlockAttributesBinding,
            isPreviewMode: $isEditorPreviewMode
        )
        .openWriteEditorContentWidth()
        .openWriteEditorLeadingInset()
        .padding(.top, DesignTokens.Spacing.spacing1)
        .padding(.bottom, DesignTokens.Spacing.spacing2)
    }

    private var focusedBlockAttributesBinding: Binding<[String: String]> {
        Binding(
            get: {
                guard let id = blockFormatting.focusedBlockID,
                      let block = editingBlocks.first(where: { $0.id == id }) else { return [:] }
                return block.attributes
            },
            set: { newValue in
                guard let id = blockFormatting.focusedBlockID,
                      let index = editingBlocks.firstIndex(where: { $0.id == id }) else { return }
                editingBlocks[index].attributes = newValue
            }
        )
    }

    private func editorActionBar(_ document: VaultDocument) -> some View {
        HStack(spacing: DesignTokens.Spacing.spacing3) {
            Spacer()

            Button {
                requestInlineRefine(preset: .improve)
            } label: {
                if inlineAssist.isRefining {
                    ProgressView()
                        .controlSize(.small)
                } else {
                    OWLabel(title: "Refine", icon: .sparkles)
                }
            }
            .buttonStyle(OWToolbarActionButtonStyle(isEnabled: inlineAssist.canRefineSelection))
            .disabled(!inlineAssist.canRefineSelection || inlineAssist.isRefining)
            .help(
                inlineAssist.canRefineSelection
                    ? "Improve selected text with local AI and vault context"
                    : "Select text in the note to refine"
            )
        }
        .frame(maxWidth: .infinity)
        .openWriteEditorLeadingInset()
        .padding(.vertical, DesignTokens.Spacing.spacing1)
    }

    private var editorScrollLayoutToken: Int {
        var token = themeManager.selectedTheme.hashValue
        if workbench.aiAssistExpanded { token |= 1 << 1 }
        if !workbench.sidebarVisible { token |= 1 << 2 }
        if workbench.navigationRailCollapsed { token |= 1 << 3 }
        return token
    }

    @ViewBuilder
    private func editorScrollSurface(_ document: VaultDocument) -> some View {
        OpenWriteThemedScrollView(
            scrollToken: editorScrollLayoutToken,
            canvasColor: palette.editorCanvas
        ) {
            VStack(alignment: .leading, spacing: 0) {
                pageBanner(document)

                VStack(alignment: .leading, spacing: 0) {
                    if !isEditorPreviewMode {
                        blockFormattingBar
                            .padding(.top, DesignTokens.Spacing.spacing2)

                        editorActionBar(document)
                            .padding(.top, DesignTokens.Spacing.spacing2)
                    } else {
                        HStack {
                            Spacer()
                            Button {
                                isEditorPreviewMode = false
                            } label: {
                                Text("Edit")
                                    .font(OWTypography.captionEmphasis)
                                    .foregroundStyle(DesignTokens.Color.accent)
                            }
                            .buttonStyle(.plain)
                            .openWriteFocusChrome()
                            .help("Return to editing")
                        }
                        .openWriteEditorLeadingInset()
                        .padding(.top, DesignTokens.Spacing.spacing2)
                    }

                    OWBlockEditorView(
                        blocks: $editingBlocks,
                        previewMode: isEditorPreviewMode,
                        onActivateBlock: { _ in
                            isEditorPreviewMode = false
                        },
                        onSelectionChange: { selectedText in
                            inlineAssist.scheduleSelectionCapture(
                                documentID: document.id,
                                blockID: blockFormatting.focusedBlockID,
                                selectedText: selectedText
                            )
                        },
                        onRefinePreset: { preset, selectedText in
                            requestInlineRefine(
                                document: document,
                                preset: preset,
                                selectedText: selectedText
                            )
                        }
                    )
                        .openWriteEditorLeadingInset()
                        .padding(.top, DesignTokens.Layout.editorHeaderToBodySpacing)
                        .onChange(of: editingBlocks) { _, newBlocks in
                            scheduleCommitBlocks(document: document, blocks: newBlocks)
                        }
                }
                .openWriteEditorContentWidth()
                .padding(.bottom, DesignTokens.Spacing.spacing4)
            }
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.editorCanvas)
    }

    private func nonEmptyProperty(_ document: VaultDocument, key: PagePropertyKey) -> String? {
        let value = document.properties.string(for: key).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func syncFromDocument(_ document: VaultDocument?) {
        guard let document else { return }
        editingBlocks = document.rootBlocks.filter { $0.kind != .property }
        if !appliedEditorPresentation {
            appliedEditorPresentation = true
        }
    }

    private func syncHeaderFromDocument(_ document: VaultDocument?) {
        guard let document else { return }
        headerTitle = document.displayTitle
        headerPageIcon = document.pageIcon
        headerCoverStyle = document.coverStyle
        headerCoverImagePath = document.coverImagePath
        headerIconOffsetX = document.pageIconOffsetX
        headerIconOffsetY = document.pageIconOffsetY
    }

    @ViewBuilder
    private var refineResultSheet: some View {
        NavigationStack {
            Group {
                switch inlineAssist.phase {
                case .refining:
                    VStack(spacing: 12) {
                        ProgressView()
                        Text("Refining selection…")
                            .font(OWTypography.callout)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                case .ready(let text, let sourceHits):
                    OpenWriteThemedScrollView(canvasColor: palette.editorCanvas) {
                        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
                            if !sourceHits.isEmpty {
                                RAGSourcePillsView(hits: sourceHits) { documentID in
                                    vaultStore.selectedDocumentID = documentID
                                }
                            }
                            Text(AIInput.stripChunkReferences(text))
                                .font(OWTypography.body)
                                .lineSpacing(OWTypography.bodyLineSpacing)
                                .textSelection(.enabled)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            if inlineAssist.canApplyRefinement {
                                Button("Apply to selection") {
                                    applyRefinementToDocument()
                                }
                                .buttonStyle(OWAccentCapsuleButtonStyle())
                            }
                        }
                        .padding()
                    }
                case .failed(let message):
                    OWEmptyState(
                        title: "Refine failed",
                        icon: .warning,
                        description: Text(message)
                    )
                default:
                    Text("No result")
                        .font(OWTypography.callout)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }
            }
            .navigationTitle("Refine selection")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { inlineAssist.dismissRefine() }
                        .buttonStyle(OWSecondaryRectButtonStyle())
                }
                if inlineAssist.canApplyRefinement {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Apply") { applyRefinementToDocument() }
                            .buttonStyle(OWAccentCapsuleButtonStyle())
                    }
                }
            }
        }
        .frame(minWidth: 420, minHeight: 280)
    }

    private func requestInlineRefine(
        document: VaultDocument,
        preset: InlineRefinePreset,
        selectedText: String
    ) {
        inlineAssist.scheduleSelectionCapture(
            documentID: document.id,
            blockID: blockFormatting.focusedBlockID,
            selectedText: selectedText
        )
        inlineAssist.commitPendingCapture()
        let excerpt = editingBlocks
            .map(\.text)
            .joined(separator: "\n")
            .prefix(1200)
        inlineAssist.refineSelection(
            using: aiServices.rag,
            preset: preset,
            noteExcerpt: String(excerpt)
        )
    }

    private func requestInlineRefine(preset: InlineRefinePreset) {
        guard let document else { return }
        inlineAssist.commitPendingCapture()
        guard inlineAssist.canRefineSelection else { return }
        let excerpt = editingBlocks
            .map(\.text)
            .joined(separator: "\n")
            .prefix(1200)
        inlineAssist.refineSelection(
            using: aiServices.rag,
            preset: preset,
            noteExcerpt: String(excerpt)
        )
    }

    private func applyRefinementToDocument() {
        guard let document,
              let snapshot = inlineAssist.latestSnapshot,
              case .ready(let refined, _) = inlineAssist.phase else { return }

        let applied = InlineAssistController.applyRefinement(
            refined,
            snapshot: snapshot,
            blocks: &editingBlocks,
            fallbackBlockID: blockFormatting.focusedBlockID
        )
        guard applied else { return }

        commitBlocks(document: document, blocks: editingBlocks)
        inlineAssist.dismissRefine()
    }

    private func scheduleCommitBlocks(document: VaultDocument, blocks: [NoteBlock]) {
        blocksCommitTask?.cancel()
        let documentID = document.id
        let title = document.displayTitle
        blocksCommitTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 450_000_000)
            guard !Task.isCancelled else { return }
            commitBlocks(documentID: documentID, noteTitle: title, blocks: blocks)
        }
    }

    private func flushPendingBlocksCommit(document: VaultDocument) {
        blocksCommitTask?.cancel()
        blocksCommitTask = nil
        commitBlocks(documentID: document.id, noteTitle: document.displayTitle, blocks: editingBlocks)
    }

    private func commitBlocks(document: VaultDocument, blocks: [NoteBlock]) {
        commitBlocks(documentID: document.id, noteTitle: document.displayTitle, blocks: blocks)
    }

    private func commitBlocks(documentID: UUID, noteTitle: String, blocks: [NoteBlock]) {
        vaultStore.updateRootBlocks(for: documentID, bodyBlocks: blocks)
        let excerpt = blocks.map(\.text).joined(separator: "\n")
        pastWrites.recordEdit(
            noteID: documentID,
            noteTitle: noteTitle,
            plainText: excerpt
        )
    }

}
