import SwiftUI

/// SwiftUI-only preview surface — no AppKit hosting (avoids empty grey preview cards).
struct EditorPreviewBlockStack: View {
    let blocks: [NoteBlock]

    var body: some View {
        LazyVStack(
            alignment: .leading,
            spacing: DesignTokens.Layout.editorBlockStackSpacing
        ) {
            ForEach(blocks) { block in
                previewRow(for: block)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func previewRow(for block: NoteBlock) -> some View {
        switch block.kind {
        case .todo:
            OWPreviewBlockRow(block: block, previewMode: true)
        case .callout:
            OWPreviewBlockRow(block: block, previewMode: true)
        case .code:
            OWPreviewBlockRow(block: block, previewMode: true)
        case .heading1, .heading2, .heading3, .paragraph, .bullet, .quote, .wikilink:
            OWPreviewBlockRow(block: block, previewMode: true)
        case .image:
            OWPreviewBlockRow(block: block, previewMode: true)
        default:
            OWPreviewBlockRow(block: block, previewMode: true)
        }
    }
}
