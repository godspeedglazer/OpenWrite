import SwiftUI

// MARK: - Scroll token

extension Array where Element == ChatMessage {
    /// Drives stick-to-bottom only on structural chat changes — not every streamed token.
    var chatScrollToken: Int {
        var hasher = Hasher()
        hasher.combine(count)
        hasher.combine(pipelineStepsTail)
        if let last = last {
            hasher.combine(last.id)
            hasher.combine(last.isStreaming)
            hasher.combine(last.isError)
            hasher.combine(last.sourceHits.count)
        }
        return hasher.finalize()
    }

    private var pipelineStepsTail: Int {
        guard let steps = last?.pipelineSteps, !steps.isEmpty else { return 0 }
        var hasher = Hasher()
        for step in steps {
            hasher.combine(step.id)
            hasher.combine(step.title)
            hasher.combine(step.status)
        }
        return hasher.finalize()
    }
}

// MARK: - Transcript

struct ChatTranscriptView: View {
    let messages: [ChatMessage]
    let scrollToken: Int
    let bottomPadding: CGFloat
    let background: Color
    @Binding var isPinnedToBottom: Bool

    @EnvironmentObject private var vaultStore: VaultStore

    var body: some View {
        ChatTranscriptScrollView(
            scrollToken: scrollToken,
            background: background,
            isPinnedToBottom: $isPinnedToBottom
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
                if messages.isEmpty {
                    emptyPlaceholder
                }
                ForEach(messages) { message in
                    ChatTranscriptMessageRow(message: message) { documentID in
                        vaultStore.selectedDocumentID = documentID
                    }
                    .id(message.id)
                }
            }
            .padding(DesignTokens.Spacing.assistStripMessageListPadding)
            .padding(.bottom, bottomPadding)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var emptyPlaceholder: some View {
        VStack(spacing: DesignTokens.Spacing.spacing2) {
            OWUnicodeIconView(icon: .sparkles, size: 22)
                .foregroundStyle(DesignTokens.Color.textTertiary)
            Text("Ask about your notes")
                .font(OWTypography.calloutEmphasis)
            Text("Answers cite your notes when search is on.")
                .font(OWTypography.caption)
                .foregroundStyle(DesignTokens.Color.textTertiary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, DesignTokens.Spacing.spacing6)
    }
}

// MARK: - Message rows

private struct ChatTranscriptMessageRow: View {
    let message: ChatMessage
    let onOpenDocument: (UUID) -> Void

    @EnvironmentObject private var workbench: WorkbenchState

    var body: some View {
        switch message.role {
        case .user:
            userMessageRow
        case .assistant:
            assistantMessageRow
        case .system:
            systemMessageRow
        }
    }

    private var userMessageRow: some View {
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.spacing1) {
            Text("You")
                .font(OWTypography.captionEmphasis)
                .foregroundStyle(DesignTokens.Color.textTertiary)

            userBubble
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private var userBubble: some View {
        let hasBody = !message.text.isEmpty || !message.attachmentNames.isEmpty
        if hasBody {
            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.spacing2) {
                if !message.attachmentNames.isEmpty {
                    attachmentNameRow(message.attachmentNames)
                }
                if !message.text.isEmpty {
                    Text(displayText)
                        .font(OWTypography.body)
                        .lineSpacing(OWTypography.bodyLineSpacing)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .textSelection(.enabled)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.vertical, DesignTokens.Spacing.spacing2)
            .background(
                DesignTokens.Color.accentMuted,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
            )
        }
    }

    private var assistantMessageRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
            if !message.pipelineSteps.isEmpty {
                OWChatStatusStepper(
                    steps: message.pipelineSteps,
                    showsStreamingDots: message.isStreaming
                        && message.pipelineSteps.contains { $0.id == "respond" && $0.status == .active }
                )
            }

            if showsAssistantBubble {
                Text("Assistant")
                    .font(OWTypography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textTertiary)

                assistantMessageBody
                    .frame(maxWidth: .infinity, alignment: .leading)

                if !message.isStreaming, !parsedActions.isEmpty {
                    assistantActionsRow(count: parsedActions.count, actions: parsedActions)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var showsAssistantBubble: Bool {
        if message.isError { return true }
        if !message.sourceHits.isEmpty { return true }
        if vaultSearchHadNoSources { return true }
        if !displayText.isEmpty { return true }
        return !message.isStreaming
    }

    private var vaultSearchHadNoSources: Bool {
        message.pipelineSteps.contains { step in
            step.id == "sources" && step.title.localizedCaseInsensitiveContains("no matching")
        }
    }

    private var systemMessageRow: some View {
        Text(displayText)
            .font(OWTypography.caption)
            .foregroundStyle(DesignTokens.Color.textSecondary)
            .italic()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignTokens.Spacing.spacing1)
            .padding(.horizontal, DesignTokens.Spacing.spacing2)
            .background(DesignTokens.Color.warning.opacity(0.12), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small))
    }

    private func attachmentNameRow(_ names: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            ForEach(names, id: \.self) { name in
                Text(name)
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .lineLimit(1)
            }
        }
    }

    @ViewBuilder
    private var assistantMessageBody: some View {
        assistantBubble {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                if !message.sourceHits.isEmpty {
                    RAGSourcePillsView(hits: message.sourceHits, onOpenDocument: onOpenDocument, compact: true)
                } else if vaultSearchHadNoSources {
                    Text("No vault sources")
                        .font(OWTypography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }

                if message.isError {
                    failureBubbleContent(displayText)
                } else if !displayText.isEmpty {
                    Text(displayText)
                        .font(OWTypography.body)
                        .lineSpacing(OWTypography.bodyLineSpacing)
                        .textSelection(.enabled)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func assistantBubble<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.vertical, DesignTokens.Spacing.spacing2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                DesignTokens.Color.surfaceElevated,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
            )
            .overlay {
                if message.isError {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                        .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
                }
            }
    }

    private func failureBubbleContent(_ text: String) -> some View {
        let parts = text.split(separator: "\n", maxSplits: 1, omittingEmptySubsequences: false)
        let title = parts.first.map(String.init) ?? "Response failed"
        let detail = parts.count > 1 ? String(parts[1]) : ""

        return VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
                OWUnicodeIconView(icon: .warningFill, size: 16, color: DesignTokens.Color.warning)
                Text(title)
                    .font(OWTypography.calloutEmphasis)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
            }
            if !detail.isEmpty {
                Text(detail)
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .textSelection(.enabled)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var displayText: String {
        let raw = message.text
        guard message.role == .assistant else { return raw }
        let parsed = OWActionScript.parse(in: raw)
        let prose = parsed.proseWithoutScripts.trimmingCharacters(in: .whitespacesAndNewlines)
        return prose.isEmpty ? AIInput.stripChunkReferences(raw) : AIInput.stripChunkReferences(prose)
    }

    private var parsedActions: [OWAction] {
        guard message.role == .assistant else { return [] }
        return OWActionScript.parse(in: message.text).actions
    }

    private func assistantActionsRow(count: Int, actions: [OWAction]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            Text(
                "Detected \(count) OpenWrite action\(count == 1 ? "" : "s") in this reply."
            )
            .font(OWTypography.caption)
            .foregroundStyle(DesignTokens.Color.textSecondary)
            .fixedSize(horizontal: false, vertical: true)

            Button {
                workbench.showEditor()
                workbench.requestApplyChatOWActions(actions)
            } label: {
                Text("Apply to open note")
                    .font(OWTypography.captionEmphasis)
            }
            .buttonStyle(OWAccentCapsuleButtonStyle())
            .help("Inserts blocks and checklist items from the assistant script into the note you have open in the editor.")
        }
        .padding(.top, DesignTokens.Spacing.spacing1)
    }
}

// MARK: - Scroll container

private enum ChatTranscriptScrollAnchor {
    static let bottom = "openwrite.chat.transcript.bottom"
    static let top = "openwrite.chat.transcript.top"
}

private struct ChatTranscriptContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ChatTranscriptTopOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private struct ChatTranscriptScrollView<Content: View>: View {
    let scrollToken: Int
    let background: Color
    @Binding var isPinnedToBottom: Bool
    @ViewBuilder var content: () -> Content
    @State private var contentHeight: CGFloat = 0
    @State private var viewportHeight: CGFloat = 0
    @State private var topOffset: CGFloat = 0

    var body: some View {
        GeometryReader { viewport in
            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: true) {
                    VStack(alignment: .leading, spacing: 0) {
                        Color.clear
                            .frame(height: 1)
                            .id(ChatTranscriptScrollAnchor.top)
                            .background(
                                GeometryReader { geometry in
                                    Color.clear.preference(
                                        key: ChatTranscriptTopOffsetKey.self,
                                        value: geometry.frame(in: .named("openwrite.chat.scroll")).minY
                                    )
                                }
                            )

                        content()
                        Color.clear
                            .frame(height: 1)
                            .id(ChatTranscriptScrollAnchor.bottom)
                    }
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: ChatTranscriptContentHeightKey.self,
                                value: geometry.size.height
                            )
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .coordinateSpace(name: "openwrite.chat.scroll")
                .background(background)
                .onAppear {
                    viewportHeight = viewport.size.height
                    DispatchQueue.main.async {
                        scrollToBottom(using: proxy, animated: false)
                    }
                }
                .onChange(of: viewport.size.height) { _, newValue in
                    viewportHeight = newValue
                    recalculatePinnedState()
                }
                .onPreferenceChange(ChatTranscriptContentHeightKey.self) { value in
                    contentHeight = value
                    recalculatePinnedState()
                }
                .onPreferenceChange(ChatTranscriptTopOffsetKey.self) { value in
                    topOffset = value
                    recalculatePinnedState()
                }
                .onChange(of: scrollToken) { _, _ in
                    guard isPinnedToBottom else { return }
                    scrollToBottom(using: proxy, animated: true)
                }
            }
        }
    }

    private func recalculatePinnedState() {
        let scrollRange = max(contentHeight - viewportHeight, 0)
        if scrollRange <= 1 {
            isPinnedToBottom = true
            return
        }
        let currentOffset = max(-topOffset, 0)
        let distanceToBottom = max(scrollRange - currentOffset, 0)
        if distanceToBottom <= 8 {
            isPinnedToBottom = true
        } else if distanceToBottom > 72 {
            isPinnedToBottom = false
        }
    }

    private func scrollToBottom(using proxy: ScrollViewProxy, animated: Bool) {
        let scroll = {
            proxy.scrollTo(ChatTranscriptScrollAnchor.bottom, anchor: .bottom)
        }
        if animated {
            withAnimation(.easeOut(duration: 0.2), scroll)
        } else {
            DispatchQueue.main.async(execute: scroll)
        }
    }
}
