import SwiftUI

/// Refine-style action plan + Apply control (shared by chat transcript and refine rail).
struct OWSuggestedActionsPanel: View {
    @Environment(\.openWritePalette) private var palette

    let actions: [OWAction]
    var applyButtonTitle: String = "Apply to open note"
    var applyHelp: String = "Runs OpenWrite actions from this reply in the note open in the editor."
    var onApply: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            actionPlanSection
            Button(applyButtonTitle, action: onApply)
                .buttonStyle(OWAccentCapsuleButtonStyle())
                .keyboardShortcut(.return, modifiers: .command)
                .help(applyHelp)
        }
    }

    private var actionPlanSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            Text("Suggested actions")
                .font(OWTypography.captionEmphasis)
                .foregroundStyle(palette.textSecondary)
            Text("Preview — blocks insert into the open note when you Apply.")
                .font(OWTypography.caption)
                .foregroundStyle(palette.textTertiary)
            EditorActionPreviews(actions: actions)
        }
        .padding(DesignTokens.Spacing.spacing2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            palette.editorCanvas.opacity(0.65),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
        )
    }
}

enum OWActionSummary {
    static func text(for action: OWAction) -> String {
        switch action {
        case .insertBlock(let kind, let text, let checked):
            if kind == .todo {
                let box = (checked ?? false) ? "☑" : "☐"
                let label = text.isEmpty ? "…" : text
                return "Insert to-do \(box) \(label)"
            }
            return "Insert \(kind.rawValue): \(text.isEmpty ? "…" : text)"
        case .insertChecklist(let items):
            return "Insert checklist (\(items.count) item\(items.count == 1 ? "" : "s"))"
        case .refreshGraph:
            return "Refresh graph view"
        }
    }

    static func applyButtonTitle(actions: [OWAction], hasProse: Bool) -> String {
        if !actions.isEmpty, hasProse {
            return "Apply text & actions"
        }
        if !actions.isEmpty {
            return "Apply actions"
        }
        return "Apply to open note"
    }
}
