import AppKit
import SwiftUI

// MARK: - OWBlockEditorView

/// Stacked WYSIWYG block editor — each NDL block is a filled card with inline editing.
struct OWBlockEditorView: View {
    @Binding var blocks: [NoteBlock]

    var body: some View {
        BlockEditorPasteHost(blocks: $blocks) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                ForEach($blocks) { $block in
                    blockRow(for: $block)
                }
            }
            .openWriteEditorContentWidth()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.bottom, DesignTokens.Spacing.spacing3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private func blockRow(for block: Binding<NoteBlock>) -> some View {
        let editableText = block.text
        switch block.wrappedValue.kind {
        case .todo:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                checked: Binding(
                    get: { block.wrappedValue.isChecked },
                    set: { block.wrappedValue.isChecked = $0 }
                )
            )
        case .callout:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                calloutType: attributeBinding(block, key: "callout")
            )
        case .code:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: editableText,
                language: attributeBinding(block, key: "language")
            )
        case .heading1, .heading2, .heading3, .paragraph, .bullet, .quote, .wikilink:
            OWPreviewBlockRow(block: block.wrappedValue, text: editableText)
        default:
            OWPreviewBlockRow(block: block.wrappedValue)
        }
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

    func makeNSView(context: Context) -> NSScrollView {
        let scrollView = NSScrollView()
        scrollView.hasVerticalScroller = true
        scrollView.autohidesScrollers = true
        scrollView.drawsBackground = false
        scrollView.borderType = .noBorder
        scrollView.autoresizingMask = [.width, .height]

        let hosting = NSHostingView(rootView: content)
        hosting.sizingOptions = [.intrinsicContentSize]
        let host = BlockEditorPasteCaptureView(hostedView: hosting)
        host.onPasteImageBlock = { block in
            context.coordinator.append(block)
        }
        scrollView.documentView = host
        layoutBlockEditorDocument(scrollView)
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let host = scrollView.documentView as? BlockEditorPasteCaptureView,
              let hosting = host.hostedView as? NSHostingView<Content> else { return }
        host.onPasteImageBlock = { block in
            context.coordinator.append(block)
        }
        hosting.rootView = content
        layoutBlockEditorDocument(scrollView)
    }

    private func layoutBlockEditorDocument(_ scrollView: NSScrollView) {
        guard let host = scrollView.documentView as? BlockEditorPasteCaptureView else { return }
        let width = max(scrollView.contentView.bounds.width, scrollView.bounds.width, 320)
        host.layoutDocument(width: width)
        let height = max(host.intrinsicContentSize.height, scrollView.bounds.height)
        host.frame = NSRect(x: 0, y: 0, width: width, height: height)
        scrollView.documentView = host
    }

    final class Coordinator {
        var blocks: Binding<[NoteBlock]>

        init(blocks: Binding<[NoteBlock]>) {
            self.blocks = blocks
        }

        func append(_ block: NoteBlock) {
            blocks.wrappedValue.append(block)
        }
    }
}
