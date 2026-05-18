import AppKit
import SwiftUI

// MARK: - OWBlockEditorView

/// Stacked WYSIWYG block editor — each NDL block is a filled card with inline editing.
struct OWBlockEditorView: View {
    @Binding var blocks: [NoteBlock]
    var previewMode: Bool = false
    var onActivateBlock: ((UUID) -> Void)? = nil
    var onSelectionChange: ((String?) -> Void)? = nil
    var onRefinePreset: ((InlineRefinePreset, String) -> Void)? = nil
    var body: some View {
        BlockEditorPasteHost(
            blocks: $blocks,
            previewMode: previewMode,
            onActivateBlock: onActivateBlock,
            onSelectionChange: onSelectionChange,
            onRefinePreset: onRefinePreset
        )
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .fixedSize(horizontal: false, vertical: true)
    }
}

// MARK: - Block editor paste host

/// Stable SwiftUI root for `NSHostingView` — keeps `NSTextView` instances alive across keystrokes.
private struct BlockEditorHostedContent: View {
    @Binding var blocks: [NoteBlock]
    var previewMode: Bool
    var onActivateBlock: ((UUID) -> Void)?
    var onSelectionChange: ((String?) -> Void)?
    var onRefinePreset: ((InlineRefinePreset, String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.editorBlockStackSpacing) {
            ForEach($blocks) { $block in
                blockRow(for: $block)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func blockRow(for block: Binding<NoteBlock>) -> some View {
        let editableText = previewMode ? nil : block.text
        let activate: () -> Void = {
            onActivateBlock?(block.wrappedValue.id)
        }
        switch block.wrappedValue.kind {
        case .todo:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                blockAttributes: attributesBinding(block),
                checked: todoCheckedBinding(block),
                onSelectionChange: onSelectionChange,
                onRefinePreset: onRefinePreset,
                previewMode: previewMode,
                onActivate: activate
            )
        case .callout:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                blockAttributes: attributesBinding(block),
                calloutType: attributeBinding(block, key: "callout"),
                onSelectionChange: onSelectionChange,
                onRefinePreset: onRefinePreset,
                previewMode: previewMode,
                onActivate: activate
            )
        case .code:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                blockAttributes: attributesBinding(block),
                language: attributeBinding(block, key: "language"),
                onSelectionChange: onSelectionChange,
                onRefinePreset: onRefinePreset,
                previewMode: previewMode,
                onActivate: activate
            )
        case .heading1, .heading2, .heading3, .paragraph, .bullet, .quote, .wikilink:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                blockAttributes: attributesBinding(block),
                onSelectionChange: onSelectionChange,
                onRefinePreset: onRefinePreset,
                previewMode: previewMode,
                onActivate: activate
            )
        case .image:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                blockAttributes: attributesBinding(block),
                previewMode: previewMode,
                onActivate: activate
            )
        default:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                previewMode: previewMode,
                onActivate: activate
            )
        }
    }

    private func todoCheckedBinding(_ block: Binding<NoteBlock>) -> Binding<Bool> {
        Binding(
            get: { block.wrappedValue.isChecked },
            set: { newValue in
                var updated = block.wrappedValue
                updated.isChecked = newValue
                block.wrappedValue = updated
            }
        )
    }

    private func attributesBinding(_ block: Binding<NoteBlock>) -> Binding<[String: String]> {
        Binding(
            get: { block.wrappedValue.attributes },
            set: { block.wrappedValue.attributes = $0 }
        )
    }

    private func attributeBinding(_ block: Binding<NoteBlock>, key: String) -> Binding<String> {
        Binding(
            get: { block.wrappedValue.attributes[key] ?? "" },
            set: { newValue in
                if newValue.isEmpty {
                    block.wrappedValue.attributes.removeValue(forKey: key)
                } else {
                    block.wrappedValue.attributes[key] = newValue
                }
            }
        )
    }
}

private struct BlockEditorPasteHost: NSViewRepresentable {
    @Binding var blocks: [NoteBlock]
    var previewMode: Bool
    var onActivateBlock: ((UUID) -> Void)?
    var onSelectionChange: ((String?) -> Void)?
    var onRefinePreset: ((InlineRefinePreset, String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(blocks: $blocks)
    }

    func makeNSView(context: Context) -> BlockEditorPasteCaptureView {
        let hosted = BlockEditorHostedContent(
            blocks: context.coordinator.blocks,
            previewMode: previewMode,
            onActivateBlock: onActivateBlock,
            onSelectionChange: onSelectionChange,
            onRefinePreset: onRefinePreset
        )
        let hosting = NSHostingView(rootView: hosted)
        hosting.openWriteSuppressFocusRing()
        hosting.sizingOptions = [.intrinsicContentSize]
        hosting.layer?.backgroundColor = NSColor.clear.cgColor
        context.coordinator.hostingView = hosting
        context.coordinator.seedHostedBlockIDs(blocks)
        let host = BlockEditorPasteCaptureView(hostedView: hosting)
        host.onPasteImage = {
            context.coordinator.ingestPastedImage()
        }
        host.onDropImageFile = { url in
            context.coordinator.ingestImageFile(url)
        }
        return host
    }

    func updateNSView(_ host: BlockEditorPasteCaptureView, context: Context) {
        host.onPasteImage = {
            context.coordinator.ingestPastedImage()
        }
        host.onDropImageFile = { url in
            context.coordinator.ingestImageFile(url)
        }
        context.coordinator.onSelectionChange = onSelectionChange
        context.coordinator.onRefinePreset = onRefinePreset
        let previewModeChanged = context.coordinator.lastPreviewMode != previewMode
        context.coordinator.lastPreviewMode = previewMode
        if let hosting = context.coordinator.hostingView {
            hosting.layer?.backgroundColor = NSColor.clear.cgColor
        }
        let themeRevision = ThemeManager.shared.revision
        let themeChanged = context.coordinator.lastThemeRevision != themeRevision
        if themeChanged {
            context.coordinator.lastThemeRevision = themeRevision
        }
        if themeChanged, let hosting = context.coordinator.hostingView {
            hosting.layer?.backgroundColor = NSColor(DesignTokens.Color.background).cgColor
        }
        if (context.coordinator.needsHostedRootRefresh(for: blocks) || previewModeChanged || themeChanged),
           let hosting = context.coordinator.hostingView {
            hosting.rootView = BlockEditorHostedContent(
                blocks: context.coordinator.blocks,
                previewMode: previewMode,
                onActivateBlock: onActivateBlock,
                onSelectionChange: { context.coordinator.onSelectionChange?($0) },
                onRefinePreset: { context.coordinator.onRefinePreset?($0, $1) }
            )
            if previewModeChanged || themeChanged {
                host.invalidateMeasurementCache()
            }
        }

        let layoutWidth = max(
            max(host.bounds.width, context.coordinator.lastProposedWidth ?? 0),
            320
        )
        let structureRevision = context.coordinator.blocksStructureRevision(blocks)
        let contentRevision = context.coordinator.blocksContentRevision(blocks)
        let widthChanged = abs((context.coordinator.lastAppliedWidth ?? 0) - layoutWidth) > 0.5
        let structureChanged = structureRevision != context.coordinator.lastStructureRevision
        let contentChanged = contentRevision != context.coordinator.lastContentRevision
        guard widthChanged || structureChanged || contentChanged else { return }

        if structureChanged || widthChanged || contentChanged {
            host.invalidateMeasurementCache()
        }
        context.coordinator.lastStructureRevision = structureRevision
        context.coordinator.lastContentRevision = contentRevision
        context.coordinator.lastAppliedWidth = layoutWidth
        context.coordinator.scheduleLayout(on: host, width: layoutWidth)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BlockEditorPasteCaptureView, context: Context) -> CGSize? {
        let width = max(proposal.width ?? 640, 320)
        context.coordinator.lastProposedWidth = width
        let size = nsView.measureDocumentSize(width: width)
        let widthChanged = abs((context.coordinator.lastAppliedWidth ?? 0) - width) > 0.5
        if widthChanged {
            context.coordinator.lastAppliedWidth = width
            context.coordinator.scheduleLayout(on: nsView, width: width)
        }
        return size
    }

    final class Coordinator {
        var blocks: Binding<[NoteBlock]>
        var onSelectionChange: ((String?) -> Void)?
        var onRefinePreset: ((InlineRefinePreset, String) -> Void)?
        weak var hostingView: NSHostingView<BlockEditorHostedContent>?
        var lastProposedWidth: CGFloat?
        var lastAppliedWidth: CGFloat?
        var lastStructureRevision: UInt64 = 0
        var lastContentRevision: UInt64 = 0
        var lastPreviewMode = false
        var lastThemeRevision: UInt = 0
        private var lastHostedBlockIDs: [UUID] = []
        private var layoutGeneration = 0

        init(blocks: Binding<[NoteBlock]>) {
            self.blocks = blocks
        }

        func seedHostedBlockIDs(_ blocks: [NoteBlock]) {
            lastHostedBlockIDs = blocks.map(\.id)
        }

        func needsHostedRootRefresh(for blocks: [NoteBlock]) -> Bool {
            let ids = blocks.map(\.id)
            guard ids != lastHostedBlockIDs else { return false }
            lastHostedBlockIDs = ids
            return true
        }

        func append(_ block: NoteBlock) {
            blocks.wrappedValue.append(block)
        }

        func replaceBlock(id: UUID, with block: NoteBlock) {
            guard let index = blocks.wrappedValue.firstIndex(where: { $0.id == id }) else { return }
            blocks.wrappedValue[index] = block
        }

        func removeBlock(id: UUID) {
            blocks.wrappedValue.removeAll { $0.id == id }
        }

        func ingestPastedImage() {
            guard ImagePasteSupport.imageFromPasteboard() != nil else { return }
            ingestImageWithPlaceholder {
                await ImagePasteSupport.finalizePastedImage()
            }
        }

        func ingestImageFile(_ url: URL) {
            ingestImageWithPlaceholder {
                await ImagePasteSupport.finalizeImage(at: url)
            }
        }

        func ingestImageWithPlaceholder(
            finalize: @escaping () async -> NoteBlock?
        ) {
            let placeholder = ImagePasteSupport.placeholderBlock()
            let blockID = placeholder.id
            append(placeholder)
            Task {
                let finalized = await finalize()
                await MainActor.run {
                    if let finalized {
                        replaceBlock(id: blockID, with: finalized)
                    } else {
                        removeBlock(id: blockID)
                    }
                }
            }
        }

        /// Text/checkbox changes that affect vertical size without block add/remove.
        func blocksContentRevision(_ blocks: [NoteBlock]) -> UInt64 {
            var hasher = Hasher()
            for block in blocks {
                hasher.combine(block.id)
                hasher.combine(block.text)
                hasher.combine(block.isChecked)
            }
            return UInt64(bitPattern: Int64(hasher.finalize()))
        }

        /// Layout-affecting block changes only — excludes `text` and `isChecked` so typing and todo toggles
        /// update SwiftUI in place without rebuilding the hosted root.
        func blocksStructureRevision(_ blocks: [NoteBlock]) -> UInt64 {
            var hasher = Hasher()
            hasher.combine(blocks.count)
            for block in blocks {
                hasher.combine(block.id)
                hasher.combine(block.kind)
                for key in block.attributes.keys.sorted() where key != NoteBlock.checkedAttributeKey {
                    hasher.combine(key)
                    hasher.combine(block.attributes[key] ?? "")
                }
            }
            return UInt64(bitPattern: Int64(hasher.finalize()))
        }

        func scheduleLayout(on host: BlockEditorPasteCaptureView, width: CGFloat) {
            layoutGeneration += 1
            let generation = layoutGeneration
            DispatchQueue.main.async { [weak host] in
                guard let host, generation == self.layoutGeneration else { return }
                host.applyDocumentLayout(width: width)
            }
        }
    }
}
