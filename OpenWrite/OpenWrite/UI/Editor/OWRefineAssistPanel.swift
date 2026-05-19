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
            OWChatStatusStepper(
                steps: inlineAssist.refinePipelineSteps,
                showsStreamingDots: inlineAssist.refinePipelineSteps.contains {
                    $0.id == "model" && $0.status == .active
                },
                layout: .refineRail
            )
            .frame(width: DesignTokens.Layout.refinePanelStepperWidth, alignment: .leading)
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
        .padding(DesignTokens.Spacing.spacing1)
        .background(
            palette.surfaceElevated,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
        }
        .openWriteFloatingShadow()
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Refine assistant")
        .animation(.easeInOut(duration: 0.32), value: inlineAssist.refinePipelineSteps)
        .onExitCommand { inlineAssist.dismissRefine() }
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
        ScrollView(.vertical, showsIndicators: true) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                HStack(alignment: .center, spacing: DesignTokens.Spacing.spacing2) {
                    OWBrandLogoSpinner(size: 28, periodSeconds: 2.2)
                    Text(inlineAssist.refineActiveStepTitle)
                        .font(OWTypography.callout)
                        .foregroundStyle(palette.textSecondary)
                }

                if !inlineAssist.streamingProse.isEmpty {
                    Text(AIInput.stripChunkReferences(inlineAssist.streamingProse))
                        .font(OWTypography.body)
                        .lineSpacing(OWTypography.bodyLineSpacing)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                } else if let preview = inlineAssist.latestSnapshot?.selectedText {
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
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var applyButtonTitle: String {
        if !inlineAssist.pendingActions.isEmpty {
            let hasProse = inlineAssist.readyProse?
                .trimmingCharacters(in: .whitespacesAndNewlines)
                .isEmpty == false
            return OWActionSummary.applyButtonTitle(
                actions: inlineAssist.pendingActions,
                hasProse: hasProse ?? false
            )
        }
        return "Apply to selection"
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
                    OWSuggestedActionsPanel(
                        actions: inlineAssist.pendingActions,
                        applyButtonTitle: applyButtonTitle,
                        applyHelp: "Apply the refined text and any suggested block actions to your selection."
                    ) {
                        onApply()
                    }
                } else if inlineAssist.canApplyRefinement {
                    Button(applyButtonTitle) { onApply() }
                        .buttonStyle(OWAccentCapsuleButtonStyle())
                        .keyboardShortcut(.return, modifiers: .command)
                        .help("Replace the selection with the refined text (⌘↩).")
                }
            }
            .padding(DesignTokens.Spacing.spacing3)
        }
    }
}
