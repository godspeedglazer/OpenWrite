import AppKit
import SwiftUI

// MARK: - OWBlockEditorView

/// Stacked WYSIWYG block editor — each NDL block is a filled card with inline editing (edit mode only).
struct OWBlockEditorView: View {
    @Binding var blocks: [NoteBlock]
    /// Width from workbench layout (`editorBodyWidth`); AppKit layout uses this exclusively.
    var columnWidth: CGFloat = 720
    var onActivateBlock: ((UUID) -> Void)? = nil
    var onSelectionChange: ((String?) -> Void)? = nil
    var onRefinePreset: ((InlineRefinePreset, String) -> Void)? = nil
    /// SwiftUI `ScrollView` ignores AppKit intrinsic height — keep measured body height in sync.
    @State private var laidOutHeight: CGFloat = 480

    var body: some View {
        let layoutWidth = max(columnWidth, 320)
        BlockEditorPasteHost(
            blocks: $blocks,
            laidOutHeight: $laidOutHeight,
            columnWidth: layoutWidth,
            onActivateBlock: onActivateBlock,
            onSelectionChange: onSelectionChange,
            onRefinePreset: onRefinePreset
        )
        .frame(width: layoutWidth, alignment: .topLeading)
        .frame(minHeight: max(laidOutHeight, 120), alignment: .topLeading)
        .clipped()
    }
}

// MARK: - Block editor paste host

/// Stable SwiftUI root for `NSHostingView` — keeps `NSTextView` instances alive across keystrokes.
private struct BlockEditorHostedContent: View {
    @Binding var blocks: [NoteBlock]
    var columnWidth: CGFloat
    var onActivateBlock: ((UUID) -> Void)?
    var onSelectionChange: ((String?) -> Void)?
    var onRefinePreset: ((InlineRefinePreset, String) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Layout.editorBlockStackSpacing) {
            ForEach($blocks) { $block in
                blockRow(for: $block)
            }
        }
        .frame(width: max(columnWidth, 320), alignment: .leading)
    }

    @ViewBuilder
    private func blockRow(for block: Binding<NoteBlock>) -> some View {
        let activate: () -> Void = {
            onActivateBlock?(block.wrappedValue.id)
        }
        switch block.wrappedValue.kind {
        case .todo:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: block.text,
                blockAttributes: attributesBinding(block),
                checked: todoCheckedBinding(block),
                onSelectionChange: onSelectionChange,
                onRefinePreset: onRefinePreset,
                onActivate: activate
            )
        case .callout:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: block.text,
                blockAttributes: attributesBinding(block),
                calloutType: attributeBinding(block, key: "callout"),
                onSelectionChange: onSelectionChange,
                onRefinePreset: onRefinePreset,
                onActivate: activate
            )
        case .code:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: block.text,
                blockAttributes: attributesBinding(block),
                language: attributeBinding(block, key: "language"),
                onSelectionChange: onSelectionChange,
                onRefinePreset: onRefinePreset,
                onActivate: activate
            )
        case .heading1, .heading2, .heading3, .paragraph, .bullet, .quote, .wikilink:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: block.text,
                blockAttributes: attributesBinding(block),
                onSelectionChange: onSelectionChange,
                onRefinePreset: onRefinePreset,
                onActivate: activate
            )
        case .image:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: block.text,
                blockAttributes: attributesBinding(block),
                onActivate: activate
            )
        default:
            OWPreviewBlockRow(
                block: block.wrappedValue,
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
    @Binding var laidOutHeight: CGFloat
    var columnWidth: CGFloat
    var onActivateBlock: ((UUID) -> Void)?
    var onSelectionChange: ((String?) -> Void)?
    var onRefinePreset: ((InlineRefinePreset, String) -> Void)?

    func makeCoordinator() -> Coordinator {
        Coordinator(blocks: $blocks, laidOutHeight: $laidOutHeight)
    }

    func makeNSView(context: Context) -> BlockEditorPasteCaptureView {
        let layoutWidth = max(columnWidth, 320)
        let hosted = BlockEditorHostedContent(
            blocks: context.coordinator.blocks,
            columnWidth: layoutWidth,
            onActivateBlock: onActivateBlock,
            onSelectionChange: onSelectionChange,
            onRefinePreset: onRefinePreset
        )
        let hosting = NSHostingView(rootView: hosted)
        hosting.openWriteSuppressFocusRing()
        hosting.sizingOptions = [.intrinsicContentSize]
        applyEditorCanvasLayer(to: hosting)
        context.coordinator.hostingView = hosting
        context.coordinator.seedHostedBlockIDs(blocks)
        let host = BlockEditorPasteCaptureView(hostedView: hosting)
        host.onPasteImage = {
            context.coordinator.ingestPastedImage()
        }
        host.onDropImageFile = { url in
            context.coordinator.ingestImageFile(url)
        }
        host.onAttachedToWindow = { [weak host, weak coordinator = context.coordinator] in
            guard let host, let coordinator else { return }
            coordinator.scheduleRefreshDocumentSizeIfContentGrew(on: host)
        }
        context.coordinator.installImagePasteObserver { [weak coordinator = context.coordinator] in
            coordinator?.ingestPastedImage()
        }
        context.coordinator.authoritativeColumnWidth = max(columnWidth, 320)
        let initialWidth = context.coordinator.resolvedLayoutWidth()
        let initialRevision = context.coordinator.blocksContentRevision(blocks)
        context.coordinator.lastStructureRevision = context.coordinator.blocksStructureRevision(blocks)
        context.coordinator.lastContentRevision = initialRevision
        context.coordinator.lastAppliedWidth = initialWidth
        host.applyDocumentLayout(width: initialWidth, contentRevision: initialRevision)
        context.coordinator.publishDocumentHeight(
            max(host.measureDocumentSize(width: initialWidth, contentRevision: initialRevision).height, 120)
        )
        DispatchQueue.main.async {
            context.coordinator.scheduleRefreshDocumentSizeIfContentGrew(on: host)
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
        let proposedWidth = max(columnWidth, 320)
        context.coordinator.authoritativeColumnWidth = proposedWidth
        let columnWidthChanged = abs((context.coordinator.lastProposedWidth ?? 0) - proposedWidth) > 0.5
        context.coordinator.lastProposedWidth = proposedWidth
        if columnWidthChanged {
            host.invalidateMeasurementCache(resetContentRevision: false)
            context.coordinator.lastPublishedHeight = 0
        }
        let themeRevision = ThemeManager.shared.revision
        let themeChanged = context.coordinator.lastThemeRevision != themeRevision
        if themeChanged {
            context.coordinator.lastThemeRevision = themeRevision
        }
        if let hosting = context.coordinator.hostingView {
            applyEditorCanvasLayer(to: hosting)
        }
        if context.coordinator.needsHostedRootRefresh(for: blocks) || themeChanged,
           let hosting = context.coordinator.hostingView {
            let layoutWidth = context.coordinator.resolvedLayoutWidth()
            hosting.rootView = BlockEditorHostedContent(
                blocks: context.coordinator.blocks,
                columnWidth: layoutWidth,
                onActivateBlock: onActivateBlock,
                onSelectionChange: { context.coordinator.onSelectionChange?($0) },
                onRefinePreset: { context.coordinator.onRefinePreset?($0, $1) }
            )
            host.invalidateMeasurementCache()
            let structureRevision = context.coordinator.blocksStructureRevision(blocks)
            let contentRevision = context.coordinator.blocksContentRevision(blocks)
            context.coordinator.lastStructureRevision = structureRevision
            context.coordinator.lastContentRevision = contentRevision
            context.coordinator.lastAppliedWidth = layoutWidth
            context.coordinator.scheduleLayout(
                on: host,
                width: layoutWidth,
                contentRevision: contentRevision
            )
            return
        }

        let layoutWidth = context.coordinator.resolvedLayoutWidth()
        let structureRevision = context.coordinator.blocksStructureRevision(blocks)
        let contentRevision = context.coordinator.blocksContentRevision(blocks)
        let widthChanged = abs((context.coordinator.lastAppliedWidth ?? 0) - layoutWidth) > 0.5
            || columnWidthChanged
        let structureChanged = structureRevision != context.coordinator.lastStructureRevision
        let contentChanged = contentRevision != context.coordinator.lastContentRevision
        guard widthChanged || structureChanged || contentChanged else { return }

        if structureChanged || widthChanged {
            host.invalidateMeasurementCache(resetContentRevision: false)
            context.coordinator.lastStructureRevision = structureRevision
            context.coordinator.lastContentRevision = contentRevision
            context.coordinator.lastAppliedWidth = layoutWidth
            context.coordinator.scheduleLayout(
                on: host,
                width: layoutWidth,
                contentRevision: contentRevision
            )
            return
        }

        // Keystrokes: NSTextViews grow in place; push height to SwiftUI (ScrollView ignores AppKit intrinsic).
        context.coordinator.lastContentRevision = contentRevision
        let measureWidth = context.coordinator.resolvedLayoutWidth()
        let measured = host.measureDocumentSize(width: measureWidth, contentRevision: contentRevision)
        context.coordinator.publishDocumentHeight(measured.height)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BlockEditorPasteCaptureView, context: Context) -> CGSize? {
        let proposedWidth = max(columnWidth, 320)
        context.coordinator.authoritativeColumnWidth = proposedWidth
        context.coordinator.lastProposedWidth = proposedWidth
        let width = context.coordinator.resolvedLayoutWidth()
        let contentRevision = context.coordinator.blocksContentRevision(blocks)
        if contentRevision == context.coordinator.lastMeasuredContentRevision,
           context.coordinator.lastPublishedHeight >= 120 {
            return CGSize(width: width, height: context.coordinator.lastPublishedHeight)
        }
        // Read-only measure — apply runs only from `updateNSView` to avoid AttributeGraph layout loops.
        let size = nsView.measureDocumentSize(width: width, contentRevision: contentRevision)
        let height = max(size.height, 120)
        context.coordinator.lastMeasuredContentRevision = contentRevision
        context.coordinator.publishDocumentHeight(height)
        return CGSize(width: width, height: height)
    }

    final class Coordinator {
        var blocks: Binding<[NoteBlock]>
        var laidOutHeight: Binding<CGFloat>
        var onSelectionChange: ((String?) -> Void)?
        var onRefinePreset: ((InlineRefinePreset, String) -> Void)?
        weak var hostingView: NSHostingView<BlockEditorHostedContent>?
        /// Workbench `editorBodyWidth` — sole layout authority (never narrow `host.bounds`).
        var authoritativeColumnWidth: CGFloat = 720
        var lastProposedWidth: CGFloat?
        var lastAppliedWidth: CGFloat?
        var lastStructureRevision: UInt64 = 0
        var lastContentRevision: UInt64 = 0
        var lastThemeRevision: UInt = 0
        private var lastHostedBlockIDs: [UUID] = []
        private var layoutGeneration = 0
        private var layoutFlushScheduled = false
        private var contentGrowthRefreshScheduled = false
        private var heightPublishWorkItem: DispatchWorkItem?
        var lastPublishedHeight: CGFloat = 0
        var lastMeasuredContentRevision: UInt64 = 0
        private var pendingLayoutWidth: CGFloat?
        private var pendingContentRevision: UInt64 = 0
        private var imagePasteObserver: NSObjectProtocol?

        init(blocks: Binding<[NoteBlock]>, laidOutHeight: Binding<CGFloat>) {
            self.blocks = blocks
            self.laidOutHeight = laidOutHeight
        }

        deinit {
            heightPublishWorkItem?.cancel()
            if let imagePasteObserver {
                NotificationCenter.default.removeObserver(imagePasteObserver)
            }
        }

        func installImagePasteObserver(handler: @escaping () -> Void) {
            guard imagePasteObserver == nil else { return }
            imagePasteObserver = NotificationCenter.default.addObserver(
                forName: .openWriteIngestPastedImage,
                object: nil,
                queue: .main
            ) { _ in
                handler()
            }
        }

        func publishDocumentHeight(_ height: CGFloat) {
            let safe = max(Self.roundedLayoutHeight(height), 120)
            lastPublishedHeight = safe
            guard abs(laidOutHeight.wrappedValue - safe) > 0.5 else { return }
            heightPublishWorkItem?.cancel()
            let work = DispatchWorkItem { [weak self] in
                guard let self else { return }
                guard abs(self.laidOutHeight.wrappedValue - safe) > 0.5 else { return }
                self.laidOutHeight.wrappedValue = safe
            }
            heightPublishWorkItem = work
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.02, execute: work)
        }

        /// After static Welcome content settles, re-apply layout if measure grew (mirrors chat scroll host).
        func scheduleRefreshDocumentSizeIfContentGrew(on host: BlockEditorPasteCaptureView) {
            let width = resolvedLayoutWidth()
            let revision = blocksContentRevision(blocks.wrappedValue)
            let probe = host.measureDocumentSize(width: width, contentRevision: revision).height
            guard probe > lastPublishedHeight + 0.5 else { return }
            guard !contentGrowthRefreshScheduled else { return }
            contentGrowthRefreshScheduled = true
            DispatchQueue.main.async { [weak self, weak host] in
                guard let self, let host else { return }
                self.contentGrowthRefreshScheduled = false
                let width = self.resolvedLayoutWidth()
                let revision = self.blocksContentRevision(self.blocks.wrappedValue)
                self.scheduleLayout(on: host, width: width, contentRevision: revision)
            }
        }

        static func roundedLayoutWidth(_ width: CGFloat) -> CGFloat {
            max(floor(max(width, 320) + 0.5), 320)
        }

        static func roundedLayoutHeight(_ height: CGFloat) -> CGFloat {
            max(floor(max(height, 1) + 0.5), 1)
        }

        /// Workbench column width only — never widen or narrow from `host.bounds`.
        func resolvedLayoutWidth() -> CGFloat {
            Self.roundedLayoutWidth(max(authoritativeColumnWidth, 320))
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
            guard ImagePasteSupport.pasteboardHasIngestibleImage else { return }
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

        func blocksContentRevision(_ blocks: [NoteBlock]) -> UInt64 {
            var hasher = Hasher()
            for block in blocks {
                hasher.combine(block.id)
                hasher.combine(block.text)
            }
            return UInt64(bitPattern: Int64(hasher.finalize()))
        }

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

        func scheduleLayout(on host: BlockEditorPasteCaptureView, width: CGFloat, contentRevision: UInt64) {
            pendingLayoutWidth = width
            pendingContentRevision = contentRevision
            layoutGeneration += 1
            guard !layoutFlushScheduled else { return }
            layoutFlushScheduled = true
            let generation = layoutGeneration
            DispatchQueue.main.async { [weak self, weak host] in
                guard let self, let host, generation == self.layoutGeneration else { return }
                self.layoutFlushScheduled = false
                guard let width = self.pendingLayoutWidth else { return }
                let revision = self.pendingContentRevision
                self.pendingLayoutWidth = nil
                host.applyDocumentLayout(width: width, contentRevision: revision)
                let measured = host.measureDocumentSize(width: width, contentRevision: revision)
                self.publishDocumentHeight(measured.height)
            }
        }
    }
}

private func applyEditorCanvasLayer(to hosting: NSHostingView<BlockEditorHostedContent>) {
    let canvas = ThemeManager.shared.palette.editorCanvas
    hosting.layer?.backgroundColor = NSColor(canvas).cgColor
}
