import SwiftUI

/// Left-rail refine assistant: circular stepper + result pane (stays beside the editor, not a center popover).
struct OWRefineAssistPanel: View {
    @Environment(\.openWritePalette) private var palette
    @ObservedObject var inlineAssist: InlineAssistController
    let sourceHits: [RetrievalHit]
    let onApply: () -> Void
    let onOpenSource: (UUID) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 0) {
            OWChatStatusStepper(steps: inlineAssist.refinePipelineSteps, showsStreamingDots: inlineAssist.isRefining)
                .frame(width: DesignTokens.Layout.refinePanelRailWidth)
                .padding(.vertical, DesignTokens.Spacing.spacing3)
                .padding(.leading, DesignTokens.Spacing.spacing2)

            Rectangle()
                .fill(palette.borderSubtle)
                .frame(width: DesignTokens.Layout.borderWidth)

            VStack(alignment: .leading, spacing: 0) {
                header
                Rectangle()
                    .fill(palette.borderSubtle)
                    .frame(height: DesignTokens.Layout.borderWidth)
                content
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(width: DesignTokens.Layout.refinePanelWidth, alignment: .topLeading)
        .frame(
            minHeight: DesignTokens.Layout.refinePanelMinHeight,
            maxHeight: DesignTokens.Layout.refinePanelMaxHeight,
            alignment: .topLeading
        )
        .background(palette.surfaceElevated)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
        }
        .openWriteFloatingShadow()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Refine assistant")
        .animation(.easeInOut(duration: 0.32), value: inlineAssist.refinePipelineSteps)
    }

    private var header: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Refine")
                    .font(OWTypography.panelTitle)
                    .foregroundStyle(palette.textPrimary)
                Text(inlineAssist.refineStatusCaption)
                    .font(OWTypography.caption)
                    .foregroundStyle(palette.textSecondary)
                    .lineLimit(2)
            }
            Spacer(minLength: 0)
            Button("Done") { inlineAssist.dismissRefine() }
                .buttonStyle(OWSecondaryRectButtonStyle())
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing3)
        .padding(.vertical, DesignTokens.Spacing.spacing2)
    }

    @ViewBuilder
    private var content: some View {
        switch inlineAssist.phase {
        case .refining:
            refiningBody
        case .ready(let text, let hits):
            resultBody(text: text, hits: hits.isEmpty ? sourceHits : hits)
        case .failed(let message):
            OWEmptyState(
                title: "Refine failed",
                icon: .warning,
                description: Text(message)
            )
            .padding(DesignTokens.Spacing.spacing3)
        default:
            Text("Select text in a block, then choose Refine.")
                .font(OWTypography.callout)
                .foregroundStyle(palette.textSecondary)
                .padding(DesignTokens.Spacing.spacing3)
        }
    }

    private var refiningBody: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            OWBrandLogoSpinner(size: 36, periodSeconds: 2.2)
            Text(inlineAssist.refineActiveStepTitle)
                .font(OWTypography.callout)
                .foregroundStyle(palette.textSecondary)
            if let preview = inlineAssist.latestSnapshot?.selectedText {
                Text(preview)
                    .font(OWTypography.caption)
                    .foregroundStyle(palette.textTertiary)
                    .lineLimit(4)
                    .padding(DesignTokens.Spacing.spacing2)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        palette.editorCanvas.opacity(0.65),
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                    )
            }
        }
        .padding(DesignTokens.Spacing.spacing3)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var applyButtonTitle: String {
        if !inlineAssist.pendingActions.isEmpty,
           let prose = inlineAssist.readyProse,
           !prose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Apply text & actions"
        }
        if !inlineAssist.pendingActions.isEmpty {
            return "Apply actions"
        }
        return "Apply to selection"
    }

    private var actionPlanSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
            Text("Suggested actions")
                .font(OWTypography.captionEmphasis)
                .foregroundStyle(palette.textSecondary)
            ForEach(Array(inlineAssist.pendingActions.enumerated()), id: \.offset) { _, action in
                Text(actionSummary(action))
                    .font(OWTypography.caption)
                    .foregroundStyle(palette.textPrimary)
            }
        }
        .padding(DesignTokens.Spacing.spacing2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            palette.editorCanvas.opacity(0.65),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
        )
    }

    private func actionSummary(_ action: OWAction) -> String {
        switch action {
        case .insertBlock(let kind, let text, let checked):
            let state = checked.map { $0 ? "checked" : "unchecked" } ?? ""
            let suffix = state.isEmpty ? "" : " (\(state))"
            return "Insert \(kind.rawValue)\(suffix): \(text.isEmpty ? "…" : text)"
        case .insertChecklist(let items):
            return "Insert checklist (\(items.count) item\(items.count == 1 ? "" : "s"))"
        case .refreshGraph:
            return "Refresh graph view"
        }
    }

    private func resultBody(text: String, hits: [RetrievalHit]) -> some View {
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
                if !hits.isEmpty {
                    RAGSourcePillsView(hits: hits, onOpenDocument: onOpenSource)
                }
                if !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(AIInput.stripChunkReferences(text))
                        .font(OWTypography.body)
                        .lineSpacing(OWTypography.bodyLineSpacing)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if !inlineAssist.pendingActions.isEmpty {
                    actionPlanSection
                }

                if inlineAssist.canApplyRefinement {
                    Button(applyButtonTitle) { onApply() }
                        .buttonStyle(OWAccentCapsuleButtonStyle())
                }
            }
            .padding(DesignTokens.Spacing.spacing3)
        }
    }
}
