import AppKit
import SwiftUI

// MARK: - OWBlockEditorView

/// Stacked WYSIWYG block editor — each NDL block is a filled card with inline editing.
struct OWBlockEditorView: View {
    @Binding var blocks: [NoteBlock]
    var onSelectionChange: ((String?) -> Void)? = nil

    var body: some View {
        BlockEditorPasteHost(blocks: $blocks) {
            VStack(alignment: .leading, spacing: DesignTokens.Layout.editorBlockStackSpacing) {
                ForEach($blocks) { $block in
                    blockRow(for: $block)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func blockRow(for block: Binding<NoteBlock>) -> some View {
        let editableText = block.text
        switch block.wrappedValue.kind {
        case .todo:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                blockAttributes: attributesBinding(block),
                checked: Binding(
                    get: { block.wrappedValue.isChecked },
                    set: { block.wrappedValue.isChecked = $0 }
                ),
                onSelectionChange: onSelectionChange
            )
        case .callout:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                blockAttributes: attributesBinding(block),
                calloutType: attributeBinding(block, key: "callout"),
                onSelectionChange: onSelectionChange
            )
        case .code:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                blockAttributes: attributesBinding(block),
                language: attributeBinding(block, key: "language"),
                onSelectionChange: onSelectionChange
            )
        case .heading1, .heading2, .heading3, .paragraph, .bullet, .quote, .wikilink:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                blockAttributes: attributesBinding(block),
                onSelectionChange: onSelectionChange
            )
        case .image:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                blockAttributes: attributesBinding(block)
            )
        default:
            OWPreviewBlockRow(block: block.wrappedValue)
        }
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

// MARK: - Block editor paste host

private struct BlockEditorPasteHost<Content: View>: NSViewRepresentable {
    @Binding var blocks: [NoteBlock]
    let content: Content

    init(blocks: Binding<[NoteBlock]>, @ViewBuilder content: () -> Content) {
        self._blocks = blocks
        self.content = content()
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(blocks: $blocks)
    }

    func makeNSView(context: Context) -> BlockEditorPasteCaptureView {
        let hosting = NSHostingView(rootView: content)
        hosting.openWriteSuppressFocusRing()
        hosting.sizingOptions = [.intrinsicContentSize]
        let host = BlockEditorPasteCaptureView(hostedView: hosting)
        host.onPasteImage = {
            context.coordinator.ingestPastedImage()
        }
        return host
    }

    func updateNSView(_ host: BlockEditorPasteCaptureView, context: Context) {
        guard let hosting = host.hostedView as? NSHostingView<Content> else { return }
        host.onPasteImage = {
            context.coordinator.ingestPastedImage()
        }
        hosting.rootView = content

        let layoutWidth = max(context.coordinator.lastProposedWidth ?? host.bounds.width, 320)
        let revision = context.coordinator.blocksRevision(blocks)
        let widthChanged = abs((context.coordinator.lastAppliedWidth ?? 0) - layoutWidth) > 0.5
        let contentChanged = revision != context.coordinator.lastBlocksRevision
        guard widthChanged || contentChanged else { return }

        if contentChanged || widthChanged {
            host.invalidateMeasurementCache()
        }
        context.coordinator.lastBlocksRevision = revision
        context.coordinator.lastAppliedWidth = layoutWidth
        context.coordinator.scheduleLayout(on: host, width: layoutWidth)
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView: BlockEditorPasteCaptureView, context: Context) -> CGSize? {
        let width = max(proposal.width ?? 640, 320)
        context.coordinator.lastProposedWidth = width
        return nsView.measureDocumentSize(width: width)
    }

    final class Coordinator {
        var blocks: Binding<[NoteBlock]>
        var lastProposedWidth: CGFloat?
        var lastAppliedWidth: CGFloat?
        var lastBlocksRevision: UInt64 = 0
        private var layoutGeneration = 0

        init(blocks: Binding<[NoteBlock]>) {
            self.blocks = blocks
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
            let placeholder = ImagePasteSupport.placeholderBlock()
            let blockID = placeholder.id
            append(placeholder)
            Task {
                let finalized = await ImagePasteSupport.finalizePastedImage()
                await MainActor.run {
                    if let finalized {
                        replaceBlock(id: blockID, with: finalized)
                    } else {
                        removeBlock(id: blockID)
                    }
                }
            }
        }

        func blocksRevision(_ blocks: [NoteBlock]) -> UInt64 {
            var hasher = Hasher()
            hasher.combine(blocks.count)
            for block in blocks {
                hasher.combine(block.id)
                hasher.combine(block.kind)
                hasher.combine(block.text)
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
