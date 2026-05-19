import SwiftUI

/// Read-only rendered note — flat typography on the editor canvas (no edit-mode block cards).
struct EditorPreviewBlockStack: View {
    let blocks: [NoteBlock]

    private var bodyBlocks: [NoteBlock] {
        blocks.filter { $0.kind != .property }
    }

    var body: some View {
        VStack(
            alignment: .leading,
            spacing: DesignTokens.Layout.editorPreviewStackSpacing
        ) {
            ForEach(bodyBlocks) { block in
                OWPreviewBlockRow(block: block, previewMode: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
