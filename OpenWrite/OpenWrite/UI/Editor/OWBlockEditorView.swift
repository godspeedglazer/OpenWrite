import AppKit
import SwiftUI

// MARK: - OWBlockEditorView

/// Stacked block editor — one inline field per NDL block (MVP: headings, paragraph, bullet, callout).
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
        switch block.wrappedValue.kind {
        case .todo:
            OWPreviewBlockRow(
                block: block.wrappedValue,
                text: block.text,
                checked: Binding(
                    get: { block.wrappedValue.isChecked },
                    set: { block.wrappedValue.isChecked = $0 }
                )
            )
        case .heading1, .heading2, .heading3, .paragraph, .bullet, .callout:
            OWPreviewBlockRow(block: block.wrappedValue, text: block.text)
        default:
            OWPreviewBlockRow(block: block.wrappedValue)
        }
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
        let host = BlockEditorPasteCaptureView(hostedView: hosting)
        host.onPasteImageBlock = { block in
            context.coordinator.append(block)
        }
        scrollView.documentView = host
        return scrollView
    }

    func updateNSView(_ scrollView: NSScrollView, context: Context) {
        guard let host = scrollView.documentView as? BlockEditorPasteCaptureView,
              let hosting = host.subviews.first as? NSHostingView<Content> else { return }
        host.onPasteImageBlock = { block in
            context.coordinator.append(block)
        }
        hosting.rootView = content
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
