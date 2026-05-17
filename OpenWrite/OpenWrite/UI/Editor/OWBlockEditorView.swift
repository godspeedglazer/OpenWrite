import SwiftUI

// MARK: - OWBlockEditorView

/// Stacked block editor — one inline field per NDL block (MVP: headings, paragraph, bullet, callout).
struct OWBlockEditorView: View {
    @Binding var blocks: [NoteBlock]

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                ForEach($blocks) { $block in
                    if Self.isEditable(block.kind) {
                        OWPreviewBlockRow(block: block, text: $block.text)
                    } else {
                        OWPreviewBlockRow(block: block)
                    }
                }
            }
            .openWriteEditorContentWidth()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.bottom, DesignTokens.Spacing.spacing3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private static func isEditable(_ kind: NoteBlock.Kind) -> Bool {
        switch kind {
        case .heading1, .heading2, .heading3, .paragraph, .bullet, .callout:
            return true
        default:
            return false
        }
    }
}
