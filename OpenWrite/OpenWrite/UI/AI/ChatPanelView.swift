import SwiftUI

struct ChatMessage: Identifiable, Hashable {
    enum Role: Hashable {
        case user
        case assistant
        case system
    }

    let id = UUID()
    let role: Role
    var text: String
    var sourceHits: [RetrievalHit]
    var isStreaming: Bool
}

@MainActor
final class ChatPanelModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var retrievalSummary: String?
    @Published var searchVaultEnabled: Bool = ChatPanelModel.initialSearchVaultEnabled()

    private static let searchVaultDefaultsKey = "com.openwrite.chat.searchVault"

    private static func initialSearchVaultEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: searchVaultDefaultsKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: searchVaultDefaultsKey)
    }

    private var streamTask: Task<Void, Never>?

    var isBusy: Bool {
        streamTask != nil
    }

    func send(services: OpenWriteAIServices, agent: AgentConfig) {
        guard let query = AIInput.sanitizeQuery(draft) else { return }
        draft = ""
        streamTask?.cancel()
        UserDefaults.standard.set(searchVaultEnabled, forKey: Self.searchVaultDefaultsKey)

        let effectiveAgent = agent.withVaultRetrieval(searchVaultEnabled)

        messages.append(ChatMessage(role: .user, text: query, sourceHits: [], isStreaming: false))
        let assistantIndex = messages.count
        messages.append(ChatMessage(role: .assistant, text: "", sourceHits: [], isStreaming: true))
        retrievalSummary = nil
        services.setActivity(effectiveAgent.toolFlags.useVaultRetrieval ? .retrieving : .connecting)

        streamTask = Task {
            do {
                let context = try await services.rag.buildContext(
                    query: query,
                    agent: effectiveAgent
                )
                await MainActor.run {
                    if assistantIndex < messages.count {
                        messages[assistantIndex].sourceHits = context.hits
                    }
                    retrievalSummary = context.hits.isEmpty
                        ? "No indexed matches · \(agent.name)"
                        : "\(context.hits.count) source\(context.hits.count == 1 ? "" : "s") · \(agent.name)"
                }

                for try await event in services.rag.streamAnswer(context: context, agent: effectiveAgent) {
                    try Task.checkCancellation()
                    await MainActor.run {
                        guard assistantIndex < messages.count else { return }
                        switch event.kind {
                        case .activity(let state):
                            services.setActivity(state)
                        case .token(let token):
                            if messages[assistantIndex].text.isEmpty {
                                services.setActivity(.streaming)
                            }
                            messages[assistantIndex].text += token
                        case .citations:
                            break
                        case .completed:
                            messages[assistantIndex].isStreaming = false
                            services.setActivity(.idle)
                            streamTask = nil
                        case .error(let message):
                            messages[assistantIndex].text = message
                            messages[assistantIndex].isStreaming = false
                            services.setActivity(.error(message))
                            streamTask = nil
                        }
                    }
                }
            } catch {
                let diagnosed = await services.diagnoseChatFailure(error)
                await MainActor.run {
                    if assistantIndex < messages.count {
                        messages[assistantIndex].text = diagnosed
                        messages[assistantIndex].isStreaming = false
                    }
                    streamTask = nil
                }
            }
        }
    }

    func clear(services: OpenWriteAIServices) {
        streamTask?.cancel()
        streamTask = nil
        messages.removeAll()
        retrievalSummary = nil
        services.setActivity(.idle)
        services.lastChatError = nil
    }
}

// MARK: - Activity indicator

struct AIActivityIndicator: View {
    let state: AIActivityState
    var retrievalSummary: String?

    @State private var pulse = false

    var body: some View {
        if state.isBusy || state.statusMessage != nil {
            HStack(alignment: .top, spacing: 10) {
                if state.isBusy {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                } else if case .error = state {
                    OWUnicodeIconView(icon: .warningFill, size: 16, color: .orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let message = state.statusMessage {
                        Text(message)
                            .font(OWTypography.caption)
                            .foregroundStyle(stateLabelColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let retrievalSummary, state == .retrieving || state == .streaming {
                        Text(retrievalSummary)
                            .font(OWTypography.caption2)
                            .foregroundStyle(.secondary)
                    }
                    if state == .streaming {
                        StreamingDots()
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(activityBackground)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.85).repeatForever(autoreverses: true)) {
                    pulse = true
                }
            }
        }
    }

    private var stateLabelColor: Color {
        if case .error = state { return .primary }
        return .secondary
    }

    private var activityBackground: Color {
        if case .error = state { return Color.orange.opacity(0.12) }
        return Color.secondary.opacity(0.08)
    }
}

private struct StreamingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(Color.accentColor.opacity(index == phase ? 1 : 0.35))
                    .frame(width: 5, height: 5)
            }
            Text("Receiving tokens")
                .font(OWTypography.caption2)
                .foregroundStyle(.tertiary)
        }
        .onAppear { startCycle() }
        .onDisappear { phase = 0 }
    }

    private func startCycle() {
        Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(320))
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Chat panel

struct ChatPanelView: View {
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var workbench: WorkbenchState
    @StateObject private var model = ChatPanelModel()

    private var navigation: AIAssistNavigationState { workbench.aiAssistNavigation }

    var body: some View {
        Group {
            switch effectiveScreen {
            case .agentPicker:
                agentPickerPanel
            case .conversation:
                conversationPanel
            }
        }
    }

    private var effectiveScreen: ChatPanelScreen {
        if navigation.current == .chatThread {
            return .conversation
        }
        return navigation.chatPanelScreen
    }

    private var agentPickerPanel: some View {
        VStack(spacing: 0) {
            OWAIPanelHeader(title: "Chat", compact: true)
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
                Text("Choose an agent")
                    .font(OWTypography.calloutEmphasis)
                    Text("Each agent uses your local index with different retrieval settings.")
                        .font(OWTypography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)

                    ForEach(AgentRegistry.pickerAgents) { agent in
                        agentRow(agent)
                    }
                }
                .padding(DesignTokens.Spacing.spacing3)
            }
        }
    }

    private func agentRow(_ agent: AgentConfig) -> some View {
        let isSelected = aiServices.selectedAgentID == agent.id
        return Button {
            aiServices.selectedAgentID = agent.id
            navigation.openChatThread()
        } label: {
            HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
                OWUnicodeIconView(icon: .agent, size: 18)
                    .foregroundStyle(DesignTokens.Color.accent)
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 4) {
                    Text(agent.name)
                        .font(OWTypography.calloutEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                    Text(agentHelp(agent))
                        .font(OWTypography.caption)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .multilineTextAlignment(.leading)
                }
                Spacer(minLength: 0)
                if isSelected {
                    OWUnicodeIconView(icon: .checkmarkCircle, size: 18, color: DesignTokens.Color.accent)
                }
            }
            .padding(DesignTokens.Spacing.spacing2)
            .background(
                isSelected
                    ? DesignTokens.Color.accentMuted
                    : DesignTokens.Color.surface.opacity(0.6),
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
            )
        }
        .buttonStyle(.plain)
    }

    private var conversationPanel: some View {
        VStack(spacing: 0) {
            conversationHeader
            AIActivityIndicator(
                state: aiServices.activityState,
                retrievalSummary: model.retrievalSummary
            )
            if aiServices.activityState.isBusy || aiServices.activityState.statusMessage != nil {
                Divider()
            }
            messageList
            Divider()
            composer
        }
    }

    private var conversationHeader: some View {
        OWAIPanelHeader(
            title: "Ask vault",
            canGoBack: showsInPanelBack,
            backAccessibilityLabel: "Back to agents",
            onBack: showsInPanelBack ? { navigation.closeChatThread() } : nil,
            compact: true,
            center: {
                VStack(alignment: .leading, spacing: 2) {
                Text("Ask vault")
                    .font(OWTypography.calloutEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                    HStack(spacing: 6) {
                        AgentPickerView(selectedAgentID: $aiServices.selectedAgentID)
                        Text(aiServices.lmConfig.chatModelDisplay)
                            .font(OWTypography.caption)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                            .lineLimit(1)
                    }
                }
            },
            trailing: {
                HStack(spacing: 8) {
                    if aiServices.activityState != .idle {
                        Text(aiServices.activityState.shortLabel)
                            .font(OWTypography.caption)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(DesignTokens.Color.surface)
                            .clipShape(Capsule())
                    }
                    Button("Clear") { model.clear(services: aiServices) }
                        .font(OWTypography.caption)
                        .disabled(model.messages.isEmpty)
                }
            }
        )
    }

    /// Strip toolbar owns back at root; full-screen `.chatThread` uses strip back only.
    private var showsInPanelBack: Bool {
        navigation.chatPanelScreen == .conversation
            && navigation.current == .chatThread
    }

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
                    if model.messages.isEmpty {
                        VStack(spacing: DesignTokens.Spacing.spacing2) {
                            OWUnicodeIconView(icon: .sparkles, size: 22)
                                .foregroundStyle(DesignTokens.Color.textTertiary)
                            Text("Ask about your notes")
                                .font(OWTypography.calloutEmphasis)
                            Text("Answers cite indexed chunks on this Mac.")
                                .font(OWTypography.caption)
                                .foregroundStyle(DesignTokens.Color.textTertiary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, DesignTokens.Spacing.spacing6)
                    }
                    ForEach(model.messages) { message in
                        messageBubble(message)
                            .id(message.id)
                    }
                }
                .padding(DesignTokens.Spacing.spacing3)
            }
            .onChange(of: model.messages.count) { _, _ in
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: streamingTail) { _, _ in
                scrollToBottom(proxy: proxy)
            }
        }
    }

    private var streamingTail: String {
        model.messages.last(where: { $0.isStreaming })?.text ?? ""
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let last = model.messages.last {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }

    @ViewBuilder
    private func messageBubble(_ message: ChatMessage) -> some View {
        VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 8) {
            if message.role == .assistant, !message.sourceHits.isEmpty {
                RAGSourcePillsView(hits: message.sourceHits) { documentID in
                    vaultStore.selectedDocumentID = documentID
                }
            }

            Group {
                if message.isStreaming, message.text.isEmpty {
                    HStack(spacing: 6) {
                        ProgressView()
                            .controlSize(.small)
                        Text(aiServices.activityState.statusMessage ?? "Waiting for model…")
                            .font(OWTypography.callout)
                            .foregroundStyle(.secondary)
                    }
                } else {
                    Text(message.text)
                        .textSelection(.enabled)
                }
            }
            .padding(DesignTokens.Spacing.spacing2)
            .font(OWTypography.callout)
            .background(bubbleColor(for: message.role))
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium))
            .frame(maxWidth: .infinity, alignment: message.role == .user ? .trailing : .leading)

            if message.isStreaming, !message.text.isEmpty {
                HStack(spacing: 4) {
                    OWUnicodeIconView(icon: .waveform, size: 12, color: DesignTokens.Color.textTertiary)
                    Text("Streaming")
                        .font(OWTypography.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func bubbleColor(for role: ChatMessage.Role) -> Color {
        switch role {
        case .user:
            return Color.accentColor.opacity(0.18)
        case .assistant:
            return Color.secondary.opacity(0.12)
        case .system:
            return Color.orange.opacity(0.12)
        }
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let lastChatError = aiServices.lastChatError, case .error = aiServices.activityState {
                Text(lastChatError)
                    .font(OWTypography.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 8) {
                Toggle("Search notes", isOn: $model.searchVaultEnabled)
                    .toggleStyle(.switch)
                    .controlSize(.small)
                    .font(OWTypography.caption)
                Spacer(minLength: 0)
                Text(aiServices.lmConfig.embeddingModelDisplay)
                    .font(OWTypography.caption2)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                    .lineLimit(1)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask about your notes…", text: $model.draft, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .font(OWTypography.body)
                    .lineLimit(1 ... 4)
                    .onSubmit { model.send(services: aiServices, agent: aiServices.selectedAgent) }

                Button {
                    aiServices.voiceInput.toggleListening(appendTo: &model.draft)
                } label: {
                    OWUnicodeIconView(
                        icon: aiServices.voiceInput.isListening ? .micActive : .mic,
                        size: 20,
                        color: aiServices.voiceInput.isListening ? Color.accentColor : .secondary
                    )
                }
                .help(aiServices.voiceInput.statusMessage ?? "Dictate into the message field")

                Button {
                    model.send(services: aiServices, agent: aiServices.selectedAgent)
                } label: {
                    OWUnicodeIconView(icon: .send, size: 24, color: DesignTokens.Color.accent)
                }
                .disabled(model.isBusy || AIInput.sanitizeQuery(model.draft) == nil)
                .keyboardShortcut(.return, modifiers: [.command])
            }
        }
        .padding(DesignTokens.Spacing.spacing3)
    }

    private func agentHelp(_ agent: AgentConfig) -> String {
        var parts = ["Retrieves up to \(agent.effectiveChunkLimit) chunks."]
        if agent.toolFlags.allowCreateNote {
            parts.append("Create-note tool enabled.")
        }
        if agent.toolFlags.passFullNoteContext {
            parts.append("Wider excerpts per chunk.")
        }
        return parts.joined(separator: " ")
    }
}
