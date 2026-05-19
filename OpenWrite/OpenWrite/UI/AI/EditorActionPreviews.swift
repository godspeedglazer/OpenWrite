import SwiftUI

/// Mini block previews for agentic `ow` actions (chat + refine Apply panels).
struct EditorActionPreviews: View {
    let actions: [OWAction]

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            ForEach(Array(actions.enumerated()), id: \.offset) { _, action in
                actionPreviewRow(action)
            }
        }
    }

    @ViewBuilder
    private func actionPreviewRow(_ action: OWAction) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
            Text(OWActionSummary.text(for: action))
                .font(OWTypography.captionEmphasis)
                .foregroundStyle(DesignTokens.Color.textSecondary)

            previewContent(for: action)
                .allowsHitTesting(false)
        }
        .padding(DesignTokens.Spacing.spacing2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DesignTokens.Color.surface.opacity(0.55),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
        }
    }

    @ViewBuilder
    private func previewContent(for action: OWAction) -> some View {
        switch action {
        case .insertBlock(let kind, let text, let checked):
            OWPreviewBlockRow(
                block: previewBlock(kind: kind, text: text, checked: checked),
                previewMode: true
            )
        case .insertChecklist(let items):
            VStack(alignment: .leading, spacing: DesignTokens.Layout.editorPreviewStackSpacing) {
                ForEach(Array(items.enumerated()), id: \.offset) { _, item in
                    OWPreviewBlockRow(
                        block: NoteBlock.todoBlock(text: item, checked: false),
                        previewMode: true
                    )
                }
            }
        case .refreshGraph:
            HStack(spacing: DesignTokens.Spacing.spacing2) {
                OWUnicodeIconView(icon: .graph, size: 16, color: DesignTokens.Color.accent)
                Text("Graph view will refresh after Apply")
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }
        }
    }

    private func previewBlock(kind: NoteBlock.Kind, text: String, checked: Bool?) -> NoteBlock {
        switch kind {
        case .todo:
            return NoteBlock.todoBlock(text: text.isEmpty ? "To-do item" : text, checked: checked ?? false)
        case .callout:
            return NoteBlock(kind: .callout, text: text.isEmpty ? "Callout" : text, attributes: ["callout": "note"])
        default:
            return NoteBlock(kind: kind, text: text.isEmpty ? "…" : text)
        }
    }
}
