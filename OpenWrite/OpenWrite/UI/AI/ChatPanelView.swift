import SwiftUI
import UniformTypeIdentifiers

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
    var attachmentNames: [String]
    var isStreaming: Bool
    var isError: Bool = false
    /// Vertical stepper state between the user turn and this assistant reply.
    var pipelineSteps: [ChatPipelineStep] = []
}

@MainActor
final class ChatPanelModel: ObservableObject {
    @Published var messages: [ChatMessage] = []
    @Published var draft: String = ""
    @Published var retrievalSummary: String?
    @Published var searchVaultEnabled: Bool = ChatPanelModel.initialSearchVaultEnabled()
    @Published var webLookupEnabled: Bool = ChatPanelModel.initialWebLookupEnabled()
    @Published var pendingAttachments: [ChatAttachment] = []
    @Published var attachmentError: String?

    private static let searchVaultDefaultsKey = "com.openwrite.chat.searchVault"
    private static let webLookupDefaultsKey = "com.openwrite.chat.webLookup"

    private static func initialSearchVaultEnabled() -> Bool {
        if UserDefaults.standard.object(forKey: searchVaultDefaultsKey) == nil { return true }
        return UserDefaults.standard.bool(forKey: searchVaultDefaultsKey)
    }

    private static func initialWebLookupEnabled() -> Bool {
        UserDefaults.standard.bool(forKey: webLookupDefaultsKey)
    }

    private var streamTask: Task<Void, Never>?
    private static let maxInMemoryMessages = 48
    /// When each pipeline step became active (per assistant message index).
    private var pipelineStepActivatedAt: [Int: [String: Date]] = [:]
    /// First streamed token time for the "Responding" dwell (whichever is later vs min delay).
    private var respondStepFirstTokenAt: [Int: Date] = [:]

    /// Intentional pacing for the vertical status stepper (tune here).
    private enum ChatPipelineTiming {
        static let stepMinimumDwell: TimeInterval = 0.55
        static let respondStepMinimumDwell: TimeInterval = 0.65
    }

    func persistComposerToggles() {
        UserDefaults.standard.set(searchVaultEnabled, forKey: Self.searchVaultDefaultsKey)
        UserDefaults.standard.set(webLookupEnabled, forKey: Self.webLookupDefaultsKey)
    }

    var isBusy: Bool {
        streamTask != nil
    }

    /// True while the assistant placeholder message is still receiving a stream.
    var hasStreamingAssistant: Bool {
        messages.contains { $0.role == .assistant && $0.isStreaming }
    }

    /// Panel chrome should stay in a loading phase until the stream task finishes or errors.
    var isChatSessionActive: Bool {
        isBusy || hasStreamingAssistant
    }

    func send(services: OpenWriteAIServices, agent: AgentConfig) {
        let attachments = pendingAttachments
        let draftText = AIInput.sanitizeQuery(draft)
        let queryText = draftText
            ?? (attachments.isEmpty ? nil : "Review the attached files and answer my question.")
        guard let query = queryText else { return }

        draft = ""
        pendingAttachments = []
        attachmentError = nil
        streamTask?.cancel()
        persistComposerToggles()

        let effectiveAgent = agent.withVaultRetrieval(searchVaultEnabled)
        let webURLs = webLookupEnabled ? WebURLExtractor.extract(from: query) : []
        let fetchesWeb = webLookupEnabled && !webURLs.isEmpty
        let attachmentNames = attachments.map(\.displayName)

        messages.append(
            ChatMessage(
                role: .user,
                text: query,
                sourceHits: [],
                attachmentNames: attachmentNames,
                isStreaming: false
            )
        )
        let assistantIndex = messages.count
        messages.append(
            ChatMessage(
                role: .assistant,
                text: "",
                sourceHits: [],
                attachmentNames: [],
                isStreaming: true,
                isError: false
            )
        )
        retrievalSummary = nil
        let searchesVault = effectiveAgent.toolFlags.useVaultRetrieval
        messages[assistantIndex].pipelineSteps = Self.initialPipelineSteps(
            searchesVault: searchesVault,
            fetchesWeb: fetchesWeb
        )
        if fetchesWeb {
            activatePipelineStep(at: assistantIndex, id: "web")
        } else if searchesVault {
            activatePipelineStep(at: assistantIndex, id: "search")
        } else {
            activatePipelineStep(at: assistantIndex, id: "connect")
        }
        if fetchesWeb {
            services.setActivity(.fetchingWeb)
        } else {
            services.setActivity(searchesVault || !attachments.isEmpty ? .retrieving : .connecting)
        }

        let priorHistory = Self.conversationHistory(before: assistantIndex, in: messages)

        streamTask = Task {
            defer {
                Task { @MainActor in
                    streamTask = nil
                    if services.activityState != .indexing {
                        services.setActivity(.idle)
                    }
                }
            }

            do {
                var webPages: [WebPageSnapshot] = []
                if fetchesWeb {
                    webPages = await services.webFetch.fetchPages(urls: webURLs)
                    await MainActor.run {
                        guard assistantIndex < messages.count else { return }
                        let count = webPages.count
                        if count > 0 {
                            updatePipelineStepTitle(
                                at: assistantIndex,
                                id: "web",
                                title: "Fetched \(count) page\(count == 1 ? "" : "s")"
                            )
                        } else {
                            updatePipelineStepTitle(at: assistantIndex, id: "web", title: "Couldn't fetch page")
                            setPipelineStep(at: assistantIndex, id: "web", status: .failed)
                        }
                    }
                    await completePipelineStep(at: assistantIndex, id: "web", skipDelay: webPages.isEmpty)
                    if webPages.isEmpty {
                        await MainActor.run {
                            guard assistantIndex < messages.count else { return }
                            messages[assistantIndex].text = """
                            Couldn't load the linked page. Turn on Web, use HTTPS, and check Settings if you use a domain allowlist.
                            """
                            messages[assistantIndex].isError = true
                            messages[assistantIndex].isStreaming = false
                            markPipelineFailed(at: assistantIndex)
                            clearPipelineTimingState(for: assistantIndex)
                            services.setActivity(.idle)
                        }
                        return
                    }
                    await MainActor.run {
                        guard assistantIndex < messages.count else { return }
                        if searchesVault {
                            activatePipelineStep(at: assistantIndex, id: "search")
                            services.setActivity(.retrieving)
                        } else {
                            activatePipelineStep(at: assistantIndex, id: "connect")
                            services.setActivity(.connecting)
                        }
                    }
                }

                let context = try await services.rag.buildContext(
                    query: query,
                    agent: effectiveAgent,
                    attachments: attachments,
                    webPages: webPages
                )
                await MainActor.run {
                    guard assistantIndex < messages.count else { return }
                    messages[assistantIndex].sourceHits = context.allHits
                    if searchesVault {
                        let pillCount = context.allHits.uniqueDocumentSources().count
                        if pillCount > 0 {
                            updatePipelineStepTitle(
                                at: assistantIndex,
                                id: "sources",
                                title: "Found \(pillCount) source\(pillCount == 1 ? "" : "s")"
                            )
                        } else {
                            updatePipelineStepTitle(at: assistantIndex, id: "sources", title: "No matching sources")
                        }
                    }
                    updatePipelineStepTitle(
                        at: assistantIndex,
                        id: "connect",
                        title: AIActivityState.connecting.connectedStatus(
                            modelDisplay: services.lmConfig.chatModelDisplay
                        )
                    )
                    retrievalSummary = Self.retrievalSummary(
                        hits: context.allHits,
                        attachmentCount: attachments.count,
                        agentName: agent.name
                    )
                    if !context.allHits.isEmpty || attachments.isEmpty {
                        services.setActivity(.connecting)
                    }
                }
                if searchesVault {
                    await completePipelineStep(at: assistantIndex, id: "search")
                    await MainActor.run {
                        guard assistantIndex < messages.count else { return }
                        activatePipelineStep(at: assistantIndex, id: "sources")
                    }
                    await completePipelineStep(at: assistantIndex, id: "sources")
                }
                await MainActor.run {
                    guard assistantIndex < messages.count else { return }
                    if messages[assistantIndex].pipelineSteps.first(where: { $0.id == "connect" })?.status != .active {
                        activatePipelineStep(at: assistantIndex, id: "connect")
                    }
                }
                await completePipelineStep(at: assistantIndex, id: "connect")
                await MainActor.run {
                    guard assistantIndex < messages.count else { return }
                    activatePipelineStep(at: assistantIndex, id: "respond")
                }

                for try await event in services.rag.streamAnswer(
                    context: context,
                    agent: effectiveAgent,
                    history: priorHistory
                ) {
                    try Task.checkCancellation()
                    switch event.kind {
                    case .activity(let state):
                        await MainActor.run {
                            guard assistantIndex < messages.count else { return }
                            if state != .idle {
                                services.setActivity(state)
                            }
                            if state == .streaming {
                                activatePipelineStep(at: assistantIndex, id: "respond")
                            }
                        }
                    case .token(let token):
                        await MainActor.run {
                            guard assistantIndex < messages.count else { return }
                            recordRespondFirstToken(at: assistantIndex)
                            services.setActivity(.streaming)
                            messages[assistantIndex].text += token
                        }
                    case .citations:
                        break
                    case .completed:
                        await MainActor.run {
                            guard assistantIndex < messages.count else { return }
                            messages[assistantIndex].text = AIInput.stripChunkReferences(
                                messages[assistantIndex].text
                            )
                            messages[assistantIndex].isStreaming = false
                        }
                        await completeRespondStep(at: assistantIndex, skipDelay: false)
                        await completePipelineStep(at: assistantIndex, id: "done")
                        await MainActor.run {
                            trimMessagesIfNeeded()
                            clearPipelineTimingState(for: assistantIndex)
                        }
                    case .error(let message):
                        await MainActor.run {
                            guard assistantIndex < messages.count else { return }
                            messages[assistantIndex].text = OpenWriteAIServices.chatFailureBubble(message: message)
                            messages[assistantIndex].isError = true
                            messages[assistantIndex].isStreaming = false
                            markPipelineFailed(at: assistantIndex)
                            clearPipelineTimingState(for: assistantIndex)
                            services.setActivity(.idle)
                            services.lastChatError = nil
                        }
                    }
                }

                let respondStillActive = await MainActor.run { () -> Bool in
                    guard assistantIndex < messages.count else { return false }
                    if messages[assistantIndex].isStreaming {
                        messages[assistantIndex].isStreaming = false
                    }
                    return messages[assistantIndex].pipelineSteps.contains { $0.id == "respond" && $0.status == .active }
                }
                if respondStillActive {
                    await completeRespondStep(at: assistantIndex, skipDelay: false)
                    await completePipelineStep(at: assistantIndex, id: "done")
                    await MainActor.run {
                        trimMessagesIfNeeded()
                        clearPipelineTimingState(for: assistantIndex)
                    }
                }
            } catch {
                let diagnosed = OpenWriteAIServices.chatFailureBubble(error, config: services.lmConfig)
                await MainActor.run {
                    if assistantIndex < messages.count {
                        messages[assistantIndex].text = diagnosed
                        messages[assistantIndex].isError = true
                        messages[assistantIndex].isStreaming = false
                        markPipelineFailed(at: assistantIndex)
                        clearPipelineTimingState(for: assistantIndex)
                    }
                    services.setActivity(.idle)
                    services.lastChatError = nil
                }
            }
        }
    }

    func importAttachments(from urls: [URL]) {
        attachmentError = nil
        var imported: [ChatAttachment] = []
        for url in urls {
            let accessed = url.startAccessingSecurityScopedResource()
            defer {
                if accessed { url.stopAccessingSecurityScopedResource() }
            }
            do {
                let attachment = try ChatAttachmentStore.importFile(from: url)
                imported.append(attachment)
            } catch {
                attachmentError = error.localizedDescription
            }
        }
        guard !imported.isEmpty else { return }
        pendingAttachments.append(contentsOf: imported)
    }

    func removePendingAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    func cancelSend(services: OpenWriteAIServices) {
        streamTask?.cancel()
        streamTask = nil
        if let index = messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
            messages[index].isStreaming = false
            if messages[index].text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                messages[index].text = "Stopped."
            }
            setPipelineStep(at: index, id: "respond", status: .completed)
            setPipelineStep(at: index, id: "done", status: .completed)
            clearPipelineTimingState(for: index)
        }
        services.setActivity(.idle)
        services.lastChatError = nil
    }

    func clear(services: OpenWriteAIServices) {
        streamTask?.cancel()
        streamTask = nil

        if !messages.isEmpty {
            let payload = messages.map { message in
                (
                    role: message.role == .user ? "user" : "assistant",
                    text: displayText(for: message),
                    isError: message.isError
                )
            }
            try? ChatSessionStore.archive(
                messages: payload,
                agentID: services.selectedAgentID
            )
        }

        messages.removeAll()
        pipelineStepActivatedAt.removeAll()
        respondStepFirstTokenAt.removeAll()
        retrievalSummary = nil
        draft = ""
        pendingAttachments = []
        attachmentError = nil
        services.setActivity(.idle)
        services.lastChatError = nil
    }

    /// Restores a thread archived via Clear (read-only transcript; user can continue by sending a new message).
    func loadArchivedThread(_ thread: SavedChatThread, services: OpenWriteAIServices) {
        streamTask?.cancel()
        streamTask = nil
        messages = thread.turns.map { turn in
            let role: ChatMessage.Role = turn.role == "user" ? .user : .assistant
            return ChatMessage(
                role: role,
                text: turn.text,
                sourceHits: [],
                attachmentNames: [],
                isStreaming: false,
                isError: false
            )
        }
        pipelineStepActivatedAt.removeAll()
        respondStepFirstTokenAt.removeAll()
        retrievalSummary = nil
        draft = ""
        pendingAttachments = []
        attachmentError = nil
        if services.selectedAgentID != thread.agentID {
            services.selectedAgentID = thread.agentID
        }
        services.setActivity(.idle)
        services.lastChatError = nil
    }

    private func displayText(for message: ChatMessage) -> String {
        let raw = message.text
        guard message.role == .assistant else { return raw }
        return AIInput.stripChunkReferences(raw)
    }

    private func trimMessagesIfNeeded() {
        guard messages.count > Self.maxInMemoryMessages else { return }
        messages.removeFirst(messages.count - Self.maxInMemoryMessages)
    }

    private static func conversationHistory(
        before assistantIndex: Int,
        in messages: [ChatMessage]
    ) -> [RAGConversationTurn] {
        guard assistantIndex > 0 else { return [] }
        var turns: [RAGConversationTurn] = []
        for message in messages.prefix(assistantIndex) {
            switch message.role {
            case .user:
                guard let text = AIInput.sanitizeQuery(message.text) else { continue }
                turns.append(RAGConversationTurn(role: .user, text: text))
            case .assistant:
                let text = AIInput.stripChunkReferences(message.text)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                guard !text.isEmpty, !message.isError else { continue }
                turns.append(RAGConversationTurn(role: .assistant, text: text))
            case .system:
                continue
            }
        }
        let maxTurns = 12
        if turns.count > maxTurns {
            return Array(turns.suffix(maxTurns))
        }
        return turns
    }

    private static func initialPipelineSteps(searchesVault: Bool, fetchesWeb: Bool = false) -> [ChatPipelineStep] {
        var steps: [ChatPipelineStep] = []
        if fetchesWeb {
            steps.append(ChatPipelineStep(id: "web", title: "Fetching page…", status: .pending))
        }
        if searchesVault {
            steps.append(ChatPipelineStep(id: "search", title: "Searching vault", status: .pending))
            steps.append(ChatPipelineStep(id: "sources", title: "Found sources", status: .pending))
        }
        steps.append(ChatPipelineStep(id: "connect", title: "Connected to model", status: .pending))
        steps.append(ChatPipelineStep(id: "respond", title: "Responding", status: .pending))
        steps.append(ChatPipelineStep(id: "done", title: "Done", status: .pending))
        return steps
    }

    private func setPipelineStep(at index: Int, id: String, status: ChatPipelineStep.Status) {
        guard index < messages.count,
              let stepIndex = messages[index].pipelineSteps.firstIndex(where: { $0.id == id }) else { return }
        messages[index].pipelineSteps[stepIndex].status = status
    }

    private func activatePipelineStep(at index: Int, id: String) {
        setPipelineStep(at: index, id: id, status: .active)
        var map = pipelineStepActivatedAt[index] ?? [:]
        map[id] = Date()
        pipelineStepActivatedAt[index] = map
    }

    private func recordRespondFirstToken(at index: Int) {
        if respondStepFirstTokenAt[index] == nil {
            respondStepFirstTokenAt[index] = Date()
        }
    }

    private func clearPipelineTimingState(for index: Int) {
        pipelineStepActivatedAt.removeValue(forKey: index)
        respondStepFirstTokenAt.removeValue(forKey: index)
    }

    private func awaitPipelineDwell(for index: Int, stepID: String, minimum: TimeInterval) async {
        let activated = await MainActor.run { pipelineStepActivatedAt[index]?[stepID] }
        let remaining: TimeInterval
        if let activated {
            remaining = minimum - Date().timeIntervalSince(activated)
        } else {
            remaining = minimum
        }
        if remaining > 0 {
            try? await Task.sleep(for: .seconds(remaining))
        }
    }

    private func completePipelineStep(at index: Int, id: String, skipDelay: Bool = false) async {
        if !skipDelay {
            await awaitPipelineDwell(for: index, stepID: id, minimum: ChatPipelineTiming.stepMinimumDwell)
        }
        await MainActor.run {
            setPipelineStep(at: index, id: id, status: .completed)
        }
    }

    private func completeRespondStep(at index: Int, skipDelay: Bool) async {
        if skipDelay {
            await MainActor.run {
                setPipelineStep(at: index, id: "respond", status: .completed)
            }
            return
        }
        let timing = await MainActor.run { () -> (activated: Date, firstToken: Date?) in
            let activated = pipelineStepActivatedAt[index]?["respond"] ?? Date()
            return (activated, respondStepFirstTokenAt[index])
        }
        var target = timing.activated.addingTimeInterval(ChatPipelineTiming.respondStepMinimumDwell)
        if let firstToken = timing.firstToken {
            target = max(target, firstToken)
        }
        let wait = target.timeIntervalSinceNow
        if wait > 0 {
            try? await Task.sleep(for: .seconds(wait))
        }
        await MainActor.run {
            setPipelineStep(at: index, id: "respond", status: .completed)
        }
    }

    private func updatePipelineStepTitle(at index: Int, id: String, title: String) {
        guard index < messages.count,
              let stepIndex = messages[index].pipelineSteps.firstIndex(where: { $0.id == id }) else { return }
        messages[index].pipelineSteps[stepIndex].title = title
    }

    private func markPipelineFailed(at index: Int) {
        guard index < messages.count else { return }
        for stepIndex in messages[index].pipelineSteps.indices {
            if messages[index].pipelineSteps[stepIndex].status == .active {
                messages[index].pipelineSteps[stepIndex].status = .failed
            } else if messages[index].pipelineSteps[stepIndex].status == .pending {
                messages[index].pipelineSteps[stepIndex].status = .failed
            }
        }
        if let doneIndex = messages[index].pipelineSteps.firstIndex(where: { $0.id == "done" }) {
            messages[index].pipelineSteps[doneIndex].title = "Failed"
            messages[index].pipelineSteps[doneIndex].status = .failed
        }
    }

    private static func retrievalSummary(hits: [RetrievalHit], attachmentCount: Int, agentName: String) -> String {
        let pillCount = hits.uniqueDocumentSources().count
        if pillCount == 0, attachmentCount == 0 {
            return "No matching notes · \(agentName)"
        }
        var parts: [String] = []
        if pillCount > 0 {
            parts.append("\(pillCount) source\(pillCount == 1 ? "" : "s")")
        }
        if attachmentCount > 0 {
            parts.append("\(attachmentCount) file\(attachmentCount == 1 ? "" : "s")")
        }
        return "\(parts.joined(separator: ", ")) · \(agentName)"
    }
}

// MARK: - Activity indicator

struct AIActivityIndicator: View {
    let state: AIActivityState
    var retrievalSummary: String?
    /// Keeps spinner/dots visible when tokens arrive but the stream has not completed.
    var isReceivingTokens: Bool = false

    @State private var pulse = false

    private var showsProgress: Bool {
        state.isBusy || isReceivingTokens
    }

    private var showsStreamingDots: Bool {
        (state == .streaming || state == .retrieving || state == .fetchingWeb || state == .connecting) && isReceivingTokens
            || (state == .streaming && !isReceivingTokens)
    }

    var body: some View {
        if showsProgress || state.statusMessage != nil || isReceivingTokens {
            HStack(alignment: .top, spacing: 10) {
                if showsProgress {
                    ProgressView()
                        .controlSize(.small)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                } else if case .error = state {
                    OWUnicodeIconView(icon: .warningFill, size: 16, color: .orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    if let message = activityMessage {
                        Text(message)
                            .font(OWTypography.caption)
                            .foregroundStyle(stateLabelColor)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    if let retrievalSummary, state == .retrieving || state == .fetchingWeb || state == .streaming || isReceivingTokens {
                        Text(retrievalSummary)
                            .font(OWTypography.caption2)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                    }
                    if showsStreamingDots {
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

    private var activityMessage: String? {
        if isReceivingTokens, state == .idle {
            return "Receiving response…"
        }
        return state.statusMessage
    }

    private var stateLabelColor: Color {
        if case .error = state { return DesignTokens.Color.textPrimary }
        return DesignTokens.Color.textSecondary
    }

    private var activityBackground: Color {
        if case .error = state { return DesignTokens.Color.warning.opacity(0.14) }
        return DesignTokens.Color.surface
    }
}

private struct StreamingDots: View {
    @State private var phase = 0

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0 ..< 3, id: \.self) { index in
                Circle()
                    .fill(DesignTokens.Color.accent.opacity(index == phase ? 1 : 0.35))
                    .frame(width: 5, height: 5)
            }
        }
        .accessibilityLabel("Receiving response")
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
    @Environment(\.aiAssistStripWidth) private var assistStripWidth
    @StateObject private var model = ChatPanelModel()
    @State private var showFileImporter = false

    private var navigation: AIAssistNavigationState { workbench.aiAssistNavigation }

    private var stripIsCompact: Bool {
        assistStripWidth < DesignTokens.Layout.assistStripDefaultWidth
    }

    var body: some View {
        Group {
            switch effectiveScreen {
            case .agentPicker:
                agentPickerPanel
            case .conversation:
                conversationPanel
            }
        }
        .onChange(of: workbench.archivedChatThreadIDToOpen) { _, threadID in
            guard let threadID, let thread = ChatSessionStore.loadThread(id: threadID) else { return }
            model.loadArchivedThread(thread, services: aiServices)
            workbench.archivedChatThreadIDToOpen = nil
            workbench.inspectorTab = .chat
            navigation.openChatThread()
        }
        .onChange(of: model.searchVaultEnabled) { _, _ in
            model.persistComposerToggles()
        }
        .onChange(of: model.webLookupEnabled) { _, _ in
            model.persistComposerToggles()
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
            OpenWriteThemedScrollView {
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
                .padding(DesignTokens.Spacing.assistStripContentPadding)
            }
            .background(DesignTokens.Color.background)
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
                    : DesignTokens.Color.surface,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .strokeBorder(
                        isSelected ? DesignTokens.Color.accent.opacity(0.3) : DesignTokens.Color.borderSubtle.opacity(0.65),
                        lineWidth: DesignTokens.Layout.borderWidth
                    )
            }
        }
        .buttonStyle(.plain)
    .openWriteFocusChrome()
    }

    private var conversationPanel: some View {
        VStack(spacing: 0) {
            conversationHeader
            messageList
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            composer
        }
        .background(DesignTokens.Color.background)
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
                    HStack(alignment: .center, spacing: 6) {
                        AgentPickerView(selectedAgentID: $aiServices.selectedAgentID)
                        Text(aiServices.lmConfig.chatModelDisplay)
                            .font(OWTypography.caption)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                            .lineLimit(1)
                    }
                }
            },
            trailing: {
                HStack(alignment: .center, spacing: 8) {
                    Button("Clear") { model.clear(services: aiServices) }
                        .buttonStyle(OWSecondaryRectButtonStyle())
                        .disabled(model.messages.isEmpty)
                }
                .frame(minHeight: 28, alignment: .center)
            }
        )
    }

    /// Strip toolbar owns back at root; full-screen `.chatThread` uses strip back only.
    private var showsInPanelBack: Bool {
        navigation.chatPanelScreen == .conversation
            && navigation.current == .chatThread
    }

    private var messageList: some View {
        OpenWriteThemedScrollView(scrollToken: chatScrollToken) {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
                if model.messages.isEmpty {
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
                ForEach(model.messages) { message in
                    messageRow(message)
                        .id(message.id)
                }
            }
            .padding(DesignTokens.Spacing.assistStripContentPadding)
        }
        .background(DesignTokens.Color.background)
    }

    private var chatScrollToken: Int {
        var hasher = Hasher()
        hasher.combine(model.messages.count)
        hasher.combine(streamingTail)
        hasher.combine(pipelineStepsTail)
        return hasher.finalize()
    }

    private var streamingTail: String {
        model.messages.last(where: { $0.isStreaming })?.text ?? ""
    }

    private var pipelineStepsTail: Int {
        model.messages.last?.pipelineSteps.count ?? 0
    }

    @ViewBuilder
    private func messageRow(_ message: ChatMessage) -> some View {
        switch message.role {
        case .user:
            userMessageRow(message)
        case .assistant:
            assistantMessageRow(message)
        case .system:
            systemMessageRow(message)
        }
    }

    private func userMessageRow(_ message: ChatMessage) -> some View {
        VStack(alignment: .trailing, spacing: DesignTokens.Spacing.spacing1) {
            Text("You")
                .font(OWTypography.captionEmphasis)
                .foregroundStyle(DesignTokens.Color.textTertiary)

            userBubble(message)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    @ViewBuilder
    private func userBubble(_ message: ChatMessage) -> some View {
        let hasBody = !message.text.isEmpty || !message.attachmentNames.isEmpty
        if hasBody {
            VStack(alignment: .trailing, spacing: DesignTokens.Spacing.spacing2) {
                if !message.attachmentNames.isEmpty {
                    attachmentNameRow(message.attachmentNames)
                }
                if !message.text.isEmpty {
                    Text(displayText(for: message))
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

    private func assistantMessageRow(_ message: ChatMessage) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
            if !message.pipelineSteps.isEmpty {
                OWChatStatusStepper(
                    steps: message.pipelineSteps,
                    showsStreamingDots: message.isStreaming
                )
                .padding(.leading, DesignTokens.Spacing.spacing1)
            }

            if showsAssistantBubble(message) {
                Text("Assistant")
                    .font(OWTypography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textTertiary)

                assistantMessageBody(message)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func showsAssistantBubble(_ message: ChatMessage) -> Bool {
        if message.isError { return true }
        if !message.sourceHits.isEmpty { return true }
        if !displayText(for: message).isEmpty { return true }
        return !message.isStreaming
    }

    private func systemMessageRow(_ message: ChatMessage) -> some View {
        Text(displayText(for: message))
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
    private func assistantMessageBody(_ message: ChatMessage) -> some View {
        assistantBubble(message: message) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                if !message.sourceHits.isEmpty {
                    RAGSourcePillsView(hits: message.sourceHits, onOpenDocument: { documentID in
                        vaultStore.selectedDocumentID = documentID
                    }, compact: true)
                }

                if message.isError {
                    failureBubbleContent(displayText(for: message))
                } else {
                    let visible = displayText(for: message)
                    if !visible.isEmpty {
                        Text(visible)
                            .font(OWTypography.body)
                            .lineSpacing(OWTypography.bodyLineSpacing)
                            .textSelection(.enabled)
                            .foregroundStyle(DesignTokens.Color.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
    }

    private func assistantBubble<Content: View>(
        message: ChatMessage,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.vertical, DesignTokens.Spacing.spacing2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                message.isError
                    ? DesignTokens.Color.warning.opacity(0.14)
                    : DesignTokens.Color.surfaceElevated,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
            )
            .overlay {
                if message.isError {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                        .strokeBorder(DesignTokens.Color.warning.opacity(0.35), lineWidth: DesignTokens.Layout.borderWidth)
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

    private func displayText(for message: ChatMessage) -> String {
        let raw = message.text
        guard message.role == .assistant else { return raw }
        return AIInput.stripChunkReferences(raw)
    }

    private var composer: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            if let attachmentError = model.attachmentError {
                Text(attachmentError)
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !model.pendingAttachments.isEmpty {
                pendingAttachmentRow
            }

            composerInputRow
        }
        .padding(DesignTokens.Spacing.assistStripContentPadding)
        .padding(.bottom, DesignTokens.Layout.assistStripComposerBottomInset)
        .safeAreaPadding(.bottom, DesignTokens.Spacing.spacing2)
        .background(DesignTokens.Color.background)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(DesignTokens.Color.borderSubtle)
                .frame(height: DesignTokens.Layout.borderWidth)
        }
    }

    private var composerInputRow: some View {
        HStack(alignment: .bottom, spacing: DesignTokens.Spacing.spacing2) {
            OWThemedComposerField(
                placeholder: stripIsCompact ? "Ask…" : "Ask about your notes…",
                text: $model.draft,
                lineLimit: 1 ... 6
            ) {
                if !model.isBusy {
                    model.send(services: aiServices, agent: aiServices.selectedAgent)
                }
            }
            .frame(maxWidth: .infinity)
            .disabled(model.isBusy)

            composerActionBoard
        }
        .fixedSize(horizontal: false, vertical: true)
    }

    /// 2×2 control board: Notes / Web on top; Attach + Send (or Stop) on bottom.
    private var composerActionBoard: some View {
        let gap = DesignTokens.Layout.composerBoardSpacing
        let iconSize = DesignTokens.Layout.composerBoardIconSize

        return VStack(spacing: gap) {
            HStack(spacing: gap) {
                OWThemedToggleButton(
                    label: "Search vault notes",
                    isOn: $model.searchVaultEnabled,
                    icon: .search,
                    showsLabel: false
                )
                .help("Search vault notes")

                OWThemedToggleButton(
                    label: "Fetch web pages",
                    isOn: $model.webLookupEnabled,
                    icon: .wiki,
                    showsLabel: false
                )
                .help("Fetch web pages")
            }

            HStack(spacing: gap) {
                Button {
                    showFileImporter = true
                } label: {
                    OWUnicodeIconView(
                        icon: .document,
                        size: iconSize,
                        color: DesignTokens.Color.textSecondary
                    )
                }
                .buttonStyle(OWComposerIconButtonStyle())
                .help("Attach file")
                .disabled(model.isBusy)
                .fileImporter(
                    isPresented: $showFileImporter,
                    allowedContentTypes: ChatAttachmentStore.allowedContentTypes,
                    allowsMultipleSelection: true
                ) { result in
                    switch result {
                    case .success(let urls):
                        model.importAttachments(from: urls)
                    case .failure(let error):
                        model.attachmentError = error.localizedDescription
                    }
                }

                if model.isBusy {
                    Button {
                        model.cancelSend(services: aiServices)
                    } label: {
                        OWUnicodeIconView(icon: .stop, size: iconSize, color: DesignTokens.Color.warning)
                    }
                    .buttonStyle(OWComposerStopButtonStyle())
                    .help("Stop generation")
                } else {
                    Button {
                        model.send(services: aiServices, agent: aiServices.selectedAgent)
                    } label: {
                        OWUnicodeIconView(
                            icon: .send,
                            size: iconSize,
                            color: DesignTokens.Color.selectionPill
                        )
                    }
                    .buttonStyle(OWComposerSendButtonStyle(isEnabled: canSendMessage))
                    .disabled(!canSendMessage)
                    .help("Send message")
                    .keyboardShortcut(.return, modifiers: [.command])
                }
            }
        }
        .fixedSize(horizontal: true, vertical: true)
    }

    private var canSendMessage: Bool {
        AIInput.sanitizeQuery(model.draft) != nil || !model.pendingAttachments.isEmpty
    }

    private var pendingAttachmentRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: DesignTokens.Spacing.spacing1) {
                ForEach(model.pendingAttachments) { attachment in
                    HStack(spacing: DesignTokens.Spacing.spacing1) {
                        Text(attachment.displayName)
                            .font(OWTypography.caption)
                            .lineLimit(1)
                        Button {
                            model.removePendingAttachment(id: attachment.id)
                        } label: {
                            Text("×")
                                .font(OWTypography.captionEmphasis)
                        }
                        .buttonStyle(.plain)
                    .openWriteFocusChrome()
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(DesignTokens.Color.surface.opacity(0.9), in: Capsule())
                }
            }
        }
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
