import SwiftUI

struct EditorView: View {
    @Environment(\.openWritePalette) private var palette
    @Environment(\.workbenchCenterLayout) private var workbenchLayout
    @Environment(\.workbenchAssistBottomBarInset) private var assistBottomBarInset
    @Environment(ThemeManager.self) private var themeManager
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var pastWrites: InMemoryPastWritesService
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @EnvironmentObject private var workbench: WorkbenchState

    let documentID: UUID
    @State private var editingBlocks: [NoteBlock]
    @State private var showProperties: Bool = false
    @State private var showTypePicker: Bool = false
    @State private var headerTitle: String
    @State private var headerPageIcon: String
    @State private var headerCoverStyle: CoverStyle?
    @State private var headerCoverImagePath: String?
    @State private var headerIconOffsetX: CGFloat
    @State private var headerIconOffsetY: CGFloat
    @State private var appliedEditorPresentation = false
    @StateObject private var inlineAssist = InlineAssistController()
    @StateObject private var blockFormatting = BlockFormattingState()
    @State private var isEditorPreviewMode = false
    @State private var blockStackLaidOutHeight: CGFloat = 0
    @State private var blocksCommitTask: Task<Void, Never>?

    init(document: VaultDocument) {
        self.documentID = document.id
        let bodyBlocks = Self.bodyBlocks(for: document)
        self._editingBlocks = State(initialValue: bodyBlocks)
        self._headerTitle = State(initialValue: document.displayTitle)
        self._headerPageIcon = State(initialValue: document.pageIcon)
        self._headerCoverStyle = State(initialValue: document.coverStyle)
        self._headerCoverImagePath = State(initialValue: document.coverImagePath)
        self._headerIconOffsetX = State(initialValue: document.pageIconOffsetX)
        self._headerIconOffsetY = State(initialValue: document.pageIconOffsetY)
    }

    init(documentID: UUID) {
        self.documentID = documentID
        // Snapshot the document at view-init time so the first render already shows blocks.
        // Falls back to the welcome sample's body for the welcome id, otherwise an empty paragraph.
        let snapshot = Self.bodySnapshot(forDocumentID: documentID)
        self._editingBlocks = State(initialValue: snapshot.blocks)
        self._headerTitle = State(initialValue: snapshot.title)
        self._headerPageIcon = State(initialValue: snapshot.icon)
        self._headerCoverStyle = State(initialValue: snapshot.coverStyle)
        self._headerCoverImagePath = State(initialValue: snapshot.coverImagePath)
        self._headerIconOffsetX = State(initialValue: snapshot.iconOffsetX)
        self._headerIconOffsetY = State(initialValue: snapshot.iconOffsetY)
    }

    private static func bodyBlocks(for document: VaultDocument) -> [NoteBlock] {
        let body = document.rootBlocks.filter { $0.kind != .property }
        return body.isEmpty ? [NoteBlock(kind: .paragraph, text: "")] : body
    }

    private struct EditorHeaderSnapshot {
        var blocks: [NoteBlock]
        var title: String
        var icon: String
        var coverStyle: CoverStyle?
        var coverImagePath: String?
        var iconOffsetX: CGFloat
        var iconOffsetY: CGFloat

        static let empty = EditorHeaderSnapshot(
            blocks: [NoteBlock(kind: .paragraph, text: "")],
            title: "",
            icon: "",
            coverStyle: nil,
            coverImagePath: nil,
            iconOffsetX: 0,
            iconOffsetY: 0
        )
    }

    /// Seeds initial state without an env-object dependency. Uses welcomeSample when the documentID
    /// matches; falls back to an empty paragraph so the body always renders something.
    private static func bodySnapshot(forDocumentID id: UUID) -> EditorHeaderSnapshot {
        if id == VaultDocument.welcomeDocumentID {
            let doc = VaultDocument.welcomeSample
            return EditorHeaderSnapshot(
                blocks: bodyBlocks(for: doc),
                title: doc.displayTitle,
                icon: doc.pageIcon,
                coverStyle: doc.coverStyle,
                coverImagePath: doc.coverImagePath,
                iconOffsetX: doc.pageIconOffsetX,
                iconOffsetY: doc.pageIconOffsetY
            )
        }
        return .empty
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
        .background(palette.editorCanvas)
        .environment(\.blockFormatting, blockFormatting)
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
        .onChange(of: isEditorPreviewMode) { _, preview in
            if preview {
                showProperties = false
                showTypePicker = false
                blockFormatting.clearActiveEditor()
            }
        }
        .onChange(of: document?.updatedAt) { _, _ in
            guard let doc = self.document else { return }
            let body = ensureEditableBodyBlocks(doc.rootBlocks.filter { $0.kind != .property })
            if editingBlocks.isEmpty, !body.isEmpty {
                syncFromDocument(doc)
                syncHeaderFromDocument(doc)
            } else if body != editingBlocks {
                syncFromDocument(doc)
            }
        }
        .onDisappear {
            if let doc = document {
                flushPendingBlocksCommit(document: doc)
            }
        }
        .onChange(of: workbench.chatOWActionsApplyToken) { _, token in
            guard token != nil, !workbench.chatOWActionsToApply.isEmpty else { return }
            applyChatOWActions(workbench.chatOWActionsToApply)
        }
    }

    private func applyChatOWActions(_ actions: [OWAction]) {
        guard let document else { return }
        let result = OWActionExecutor.apply(
            actions,
            to: editingBlocks,
            insertAfter: blockFormatting.focusedBlockID
        )
        editingBlocks = result.blocks
        if result.graphRefreshRequested {
            workbench.graphRefreshToken += 1
        }
        commitBlocks(document: document, blocks: editingBlocks)
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
        .safeAreaInset(edge: .leading, spacing: DesignTokens.Spacing.spacing2) {
            if inlineAssist.showRefineResult {
                refineAssistColumn
                    .transition(.move(edge: .leading).combined(with: .opacity))
            }
        }
        .animation(DesignTokens.Motion.animationStandard, value: inlineAssist.showRefineResult)
    }

    private var refineAssistColumn: some View {
        OWRefineAssistPanel(
            inlineAssist: inlineAssist,
            sourceHits: inlineAssist.phase.sourceHits,
            onApply: { applyRefinementToDocument() },
            onOpenSource: { vaultStore.selectedDocumentID = $0 }
        )
        .padding(.top, DesignTokens.Spacing.spacing2)
        .frame(maxHeight: .infinity, alignment: .top)
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

            if showProperties, !isEditorPreviewMode {
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
                .disabled(isEditorPreviewMode)
                .opacity(isEditorPreviewMode ? 0.45 : 1)
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
        .openWriteEditorChromeRow()
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
                editingBlocks = ensureEditableBodyBlocks(
                    VaultDocument.welcomeSample.rootBlocks.filter { $0.kind != .property }
                )
                commitBlocks(document: doc, blocks: editingBlocks)
            }
            .buttonStyle(.plain)
            .openWriteFocusChrome()
            .font(OWTypography.captionEmphasis)
            .foregroundStyle(DesignTokens.Color.accent)
        }
        .openWriteEditorChromeRow()
    }

    private var blockFormattingBar: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            OWBlockFormattingToolbar(
                formatting: blockFormatting,
                blockAttributes: focusedBlockAttributesBinding,
                isPreviewMode: $isEditorPreviewMode
            )

            HStack(spacing: DesignTokens.Spacing.spacing2) {
                EditorBlockInsertMenu(
                    onInsert: { insertBlock($0) },
                    onInsertImageFile: { url in ingestImageFileIntoDocument(url) }
                )
                Spacer(minLength: 0)
                refineChromeButton
            }
        }
        .openWriteEditorChromeRow()
        .padding(.top, DesignTokens.Spacing.spacing1)
        .padding(.bottom, DesignTokens.Spacing.spacing2)
    }

    @ViewBuilder
    private var refineChromeButton: some View {
        Button {
            requestInlineRefine(preset: .improve)
        } label: {
            if inlineAssist.isRefining {
                OWBrandLogoSpinner(size: 18, periodSeconds: 1.8)
            } else {
                OWLabel(title: "Refine", icon: .sparkles)
            }
        }
        .buttonStyle(OWToolbarActionButtonStyle(isEnabled: !inlineAssist.isRefining))
        .disabled(inlineAssist.isRefining)
        .help(
            inlineAssist.canRefineSelection
                ? "Improve selected text with local AI and vault context"
                : "Refine — select text in a block first, or open the assistant for guidance"
        )
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

    private var editorScrollToken: Int {
        var hasher = Hasher()
        hasher.combine(editingBlocks.count)
        hasher.combine(Int(resolvedBlockColumnWidth.rounded()))
        if blockStackLaidOutHeight > 0 {
            hasher.combine(Int(blockStackLaidOutHeight.rounded()))
        }
        for block in editingBlocks {
            hasher.combine(block.id)
            hasher.combine(block.kind)
        }
        return hasher.finalize()
    }

    @ViewBuilder
    private func editorScrollSurface(_ document: VaultDocument) -> some View {
        OpenWriteThemedScrollView(
            scrollToken: editorScrollToken,
            canvasColor: palette.editorCanvas,
            scrollToBottomOnTokenChange: false,
            scrollToTopToken: isEditorPreviewMode ? 1 : 0
        ) {
            editorBlocksStack(document)
                .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            editorHeaderChrome(document)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.editorCanvas)
        .onChange(of: isEditorPreviewMode) { _, preview in
            if preview {
                blockFormatting.clearActiveEditor()
                blockStackLaidOutHeight = 0
            }
        }
        .onPasteCommand(of: [.png, .tiff, .jpeg, .heic, .image, .fileURL]) { _ in
            ingestPastedImageIntoDocument()
        }
    }

    @ViewBuilder
    private func editorHeaderChrome(_ document: VaultDocument) -> some View {
        pageBanner(document)
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .background(palette.editorCanvas)
    }

    @ViewBuilder
    private func editorBlocksStack(_ document: VaultDocument) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            Color.clear
                .frame(height: 0)
                .id("openwrite.editor.blocks.top")

            if !isEditorPreviewMode {
                blockFormattingBar
            } else {
                previewReturnBar
                    .openWriteEditorChromeRow()
                    .padding(.bottom, DesignTokens.Spacing.spacing2)
            }

            Group {
                if isEditorPreviewMode {
                    EditorPreviewBlockStack(blocks: editingBlocks)
                } else {
                    OWBlockEditorView(
                        blocks: $editingBlocks,
                        columnWidth: resolvedBlockColumnWidth,
                        onActivateBlock: { blockFormatting.requestFocus(blockID: $0) },
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
                        },
                        onSplitAtCursor: { blockID, offset in
                            handleBlockSplit(blockID: blockID, cursorOffset: offset, document: document)
                        },
                        onMergeWithPrevious: { blockID in
                            handleBlockMerge(blockID: blockID, document: document)
                        },
                        focusRequestNonce: blockFormatting.focusRequestNonce,
                        focusRequestBlockID: blockFormatting.focusRequestBlockID,
                        onLaidOutHeightChange: { height in
                            let rounded = floor(height + 0.5)
                            guard abs(blockStackLaidOutHeight - rounded) > 0.5 else { return }
                            blockStackLaidOutHeight = rounded
                        },
                        insertAfterBlockID: blockFormatting.focusedBlockID,
                        onBlocksStructureChange: {
                            scheduleCommitBlocks(document: document, blocks: editingBlocks)
                        }
                    )
                }
            }
            .frame(width: resolvedBlockColumnWidth, alignment: .leading)
            .openWriteEditorFullWidth(alignment: .leading)
            .openWriteEditorLeadingInset()
            .padding(.top, DesignTokens.Spacing.spacing2)
            .padding(
                .bottom,
                DesignTokens.Layout.editorScrollBottomCushion + assistBottomBarInset
            )
            .id(isEditorPreviewMode ? "openwrite.editor.preview" : "openwrite.editor.edit")
            .onChange(of: editingBlocks) { _, newBlocks in
                scheduleCommitBlocks(document: document, blocks: newBlocks)
            }
        }
    }

    /// Block column width from workbench layout (`safeAreaInset` handles refine rail inset).
    private var resolvedBlockColumnWidth: CGFloat {
        max(workbenchLayout.editorBodyWidth, 320)
    }

    private var previewReturnBar: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            Button {
                isEditorPreviewMode = false
            } label: {
                HStack(spacing: DesignTokens.Spacing.spacing1) {
                    Text("←")
                        .font(OWTypography.captionEmphasis)
                    Text("Back to editing")
                        .font(OWTypography.captionEmphasis)
                }
                .foregroundStyle(DesignTokens.Color.accent)
                .padding(.horizontal, DesignTokens.Spacing.spacing2)
                .padding(.vertical, 6)
                .background(
                    DesignTokens.Color.accent.opacity(0.12),
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                )
            }
            .buttonStyle(.plain)
            .openWriteFocusChrome()
            Spacer(minLength: 0)
        }
        .openWriteEditorChromeRow()
    }

    private func nonEmptyProperty(_ document: VaultDocument, key: PagePropertyKey) -> String? {
        let value = document.properties.string(for: key).trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }

    private func syncFromDocument(_ document: VaultDocument?) {
        guard let document else { return }
        editingBlocks = ensureEditableBodyBlocks(document.rootBlocks.filter { $0.kind != .property })
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
        guard inlineAssist.latestSnapshot != nil else {
            inlineAssist.presentRefineMessage(
                "Select text inside a block (drag across words), then choose Refine again."
            )
            return
        }
        inlineAssist.beginRefineSession()
        startRefineTask(document: document, preset: preset)
    }

    private func requestInlineRefine(preset: InlineRefinePreset) {
        guard let document else { return }
        if let capture = blockFormatting.refineSelectionSnapshot() {
            inlineAssist.scheduleSelectionCapture(
                documentID: document.id,
                blockID: capture.blockID,
                selectedText: capture.text
            )
            requestInlineRefine(
                document: document,
                preset: preset,
                selectedText: capture.text
            )
            return
        }
        inlineAssist.commitPendingCapture()
        guard inlineAssist.latestSnapshot != nil else {
            inlineAssist.presentRefineMessage(
                "Place the cursor in a block with text, or select a passage, then choose Refine."
            )
            return
        }
        inlineAssist.beginRefineSession()
        startRefineTask(document: document, preset: preset)
    }

    private func startRefineTask(document: VaultDocument, preset: InlineRefinePreset) {
        Task {
            if let lmMessage = await ensureLMReadyForRefine() {
                await MainActor.run { inlineAssist.presentRefineMessage(lmMessage) }
                return
            }
            await MainActor.run {
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
        }
    }

    private func ensureLMReadyForRefine() async -> String? {
        await MainActor.run {
            if inlineAssist.isRefining {
                inlineAssist.setRefineModelStepTitle("Checking LM Studio…")
            }
        }
        if aiServices.lmConnectionState == .notChecked
            || aiServices.lmConnectionState == .checking
            || aiServices.lmConnectionState == .connecting {
            await aiServices.checkConnection()
        }
        if aiServices.lmConnectionState == .connecting {
            try? await Task.sleep(nanoseconds: 350_000_000)
            await aiServices.checkConnection(silent: true)
        }
        return await MainActor.run {
            Self.refineLMUnavailableMessage(connectionState: aiServices.lmConnectionState)
        }
    }

    private static func refineLMUnavailableMessage(
        connectionState: OpenWriteAIServices.LMConnectionState
    ) -> String? {
        RefineAvailability.refineBlockedMessage(connectionState: connectionState)
    }

    private func handleBlockSplit(blockID: UUID, cursorOffset: Int, document: VaultDocument) {
        guard let result = BlockKeyboardEditing.split(
            blocks: &editingBlocks,
            blockID: blockID,
            cursorOffset: cursorOffset
        ) else { return }
        blockFormatting.requestFocus(blockID: result.focusBlockID)
        commitBlocks(document: document, blocks: editingBlocks)
    }

    private func handleBlockMerge(blockID: UUID, document: VaultDocument) {
        guard let result = BlockKeyboardEditing.mergeWithPrevious(blocks: &editingBlocks, blockID: blockID) else {
            return
        }
        blockFormatting.requestFocus(blockID: result.focusBlockID)
        commitBlocks(document: document, blocks: editingBlocks)
    }

    private func insertBlock(_ block: NoteBlock) {
        BlockDocumentEditing.insert(
            block,
            into: &editingBlocks,
            after: blockFormatting.focusedBlockID
        )
        if let document {
            commitBlocks(document: document, blocks: editingBlocks)
        }
    }

    private func ingestPastedImageIntoDocument() {
        guard !isEditorPreviewMode else { return }
        BlockDocumentEditing.ingestImage(
            into: $editingBlocks,
            after: blockFormatting.focusedBlockID,
            onSettled: { [self] in
                guard let document else { return }
                scheduleCommitBlocks(document: document, blocks: editingBlocks)
            }
        )
    }

    private func ingestImageFileIntoDocument(_ url: URL) {
        guard !isEditorPreviewMode else { return }
        BlockDocumentEditing.ingestImageFile(
            at: url,
            into: $editingBlocks,
            after: blockFormatting.focusedBlockID,
            onSettled: { [self] in
                guard let document else { return }
                scheduleCommitBlocks(document: document, blocks: editingBlocks)
            }
        )
    }

    private func applyRefinementToDocument() {
        guard let document,
              let snapshot = inlineAssist.latestSnapshot,
              case .ready(let refined, _) = inlineAssist.phase else { return }

        var didChange = false

        if !inlineAssist.pendingActions.isEmpty {
            let result = OWActionExecutor.apply(
                inlineAssist.pendingActions,
                to: editingBlocks,
                insertAfter: blockFormatting.focusedBlockID ?? snapshot.blockID
            )
            editingBlocks = result.blocks
            didChange = true
            if result.graphRefreshRequested {
                workbench.graphRefreshToken += 1
            }
        }

        let prose = refined.trimmingCharacters(in: .whitespacesAndNewlines)
        if !prose.isEmpty {
            didChange = InlineAssistController.applyRefinement(
                prose,
                snapshot: snapshot,
                blocks: &editingBlocks,
                fallbackBlockID: blockFormatting.focusedBlockID
            ) || didChange
        }

        guard didChange else { return }

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
        commitBlocks(
            documentID: document.id,
            noteTitle: document.displayTitle,
            blocks: ensureEditableBodyBlocks(blocks)
        )
    }

    private func commitBlocks(documentID: UUID, noteTitle: String, blocks: [NoteBlock]) {
        let stableBlocks = ensureEditableBodyBlocks(blocks)
        vaultStore.updateRootBlocks(for: documentID, bodyBlocks: stableBlocks)
        let excerpt = stableBlocks.map(\.text).joined(separator: "\n")
        pastWrites.recordEdit(
            noteID: documentID,
            noteTitle: noteTitle,
            plainText: excerpt
        )
        aiServices.scheduleIndex(documentID: documentID, vaultStore: vaultStore)
    }

    private func ensureEditableBodyBlocks(_ blocks: [NoteBlock]) -> [NoteBlock] {
        if !blocks.isEmpty { return blocks }
        return [NoteBlock(kind: .paragraph, text: "")]
    }

}
