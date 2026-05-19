import SwiftUI

/// Inserts NDL blocks after the focused row (or at the end of the note).
struct EditorBlockInsertMenu: View {
    let onInsert: (NoteBlock) -> Void

    var body: some View {
        Menu {
            section("Basic") {
                item("Paragraph", kind: .paragraph)
                item("Heading 1", kind: .heading1)
                item("Heading 2", kind: .heading2)
                item("Heading 3", kind: .heading3)
            }
            section("Lists") {
                item("Bullet", kind: .bullet)
                Button("Checklist (2 tasks)") {
                    onInsert(NoteBlock.todoBlock(text: "", checked: false))
                    onInsert(NoteBlock.todoBlock(text: "", checked: false))
                }
                item("To-do", kind: .todo)
            }
            section("Rich") {
                item("Quote", kind: .quote)
                item("Callout", kind: .callout, attributes: ["callout": "note"])
                item("Code", kind: .code)
                item("Divider", kind: .divider)
                item("Wikilink", kind: .wikilink, text: "[[Page title]]")
            }
            section("Media") {
                Button("Image…") {
                    ImagePasteSupport.presentImagePicker { url in
                        guard let url else { return }
                        Task {
                            if let block = await ImagePasteSupport.finalizeImage(at: url) {
                                await MainActor.run { onInsert(block) }
                            }
                        }
                    }
                }
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.spacing1) {
                Text("+")
                    .font(OWTypography.captionEmphasis)
                Text("Block")
                    .font(OWTypography.captionEmphasis)
            }
            .foregroundStyle(DesignTokens.Color.accent)
            .padding(.horizontal, DesignTokens.Spacing.spacing2)
            .padding(.vertical, 6)
            .background(
                DesignTokens.Color.accent.opacity(0.12),
                in: Capsule(style: .continuous)
            )
        }
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Add a new block after the current one (⌘↩ inserts a paragraph)")
    }

    @ViewBuilder
    private func section(_ title: String, @ViewBuilder content: () -> some View) -> some View {
        Section(title) { content() }
    }

    private func item(
        _ title: String,
        kind: NoteBlock.Kind,
        text: String = "",
        attributes: [String: String] = [:]
    ) -> some View {
        Button(title) {
            onInsert(NoteBlock(kind: kind, text: text, attributes: attributes))
        }
    }
}
