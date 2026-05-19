import AppKit
import SwiftUI

private struct ChatPanelStreamError: LocalizedError {
    let message: String
    var errorDescription: String? { message }
}

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
    /// Image files sent with this user turn (for vision history on follow-up questions).
    var visionAttachments: [ChatAttachment] = []
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
                visionAttachments: attachments.filter { $0.kind == .image },
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
        mutateMessage(at: assistantIndex) { message in
            message.pipelineSteps = Self.initialPipelineSteps(
                searchesVault: searchesVault,
                fetchesWeb: fetchesWeb
            )
        }
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
                streamTask = nil
                if services.activityState != .indexing {
                    services.setActivity(.idle)
                }
            }

            var didEstablishStream = false
            do {
                var webPages: [WebPageSnapshot] = []
                if fetchesWeb {
                    webPages = await services.webFetch.fetchPages(urls: webURLs)
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
                    await completePipelineStep(at: assistantIndex, id: "web", skipDelay: webPages.isEmpty)
                    if webPages.isEmpty {
                        mutateMessage(at: assistantIndex) { message in
                            message.text = """
                            Couldn't load the linked page. Turn on Web, use HTTPS, and check Settings if you use a domain allowlist.
                            """
                            message.isError = true
                            message.isStreaming = false
                        }
                        markPipelineFailed(at: assistantIndex)
                        clearPipelineTimingState(for: assistantIndex)
                        services.setActivity(.idle)
                        return
                    }
                    if searchesVault {
                        activatePipelineStep(at: assistantIndex, id: "search")
                        services.setActivity(.retrieving)
                    } else {
                        activatePipelineStep(at: assistantIndex, id: "connect")
                        services.setActivity(.connecting)
                    }
                }

                let (context, vaultSearchTimedOut) = try await Self.buildRAGContextWithTimeout(
                    services: services,
                    query: query,
                    agent: effectiveAgent,
                    attachments: attachments,
                    webPages: webPages,
                    searchesVault: searchesVault
                )

                guard assistantIndex < messages.count else { return }
                if vaultSearchTimedOut {
                    updatePipelineStepTitle(at: assistantIndex, id: "search", title: "Vault search timed out")
                }
                mutateMessage(at: assistantIndex) { message in
                    message.sourceHits = context.allHits
                }
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
                retrievalSummary = Self.retrievalSummary(
                    hits: context.allHits,
                    attachmentCount: attachments.count,
                    agentName: agent.name
                )
                services.setActivity(.connecting)

                if searchesVault {
                    await completePipelineStep(at: assistantIndex, id: "search")
                    activatePipelineStep(at: assistantIndex, id: "sources")
                    await completePipelineStep(at: assistantIndex, id: "sources")
                }
                if messages[assistantIndex].pipelineSteps.first(where: { $0.id == "connect" })?.status != .active {
                    activatePipelineStep(at: assistantIndex, id: "connect")
                }
                updatePipelineStepTitle(
                    at: assistantIndex,
                    id: "connect",
                    title: "Connecting to \(services.lmConfig.chatModelDisplay)…"
                )

                // Do not complete "connect" until the HTTP stream succeeds (first token or `.streaming`).
                var connectStepFinished = false
                let connectDeadline = Date().addingTimeInterval(AISafetyLimits.chatStreamTimeoutSeconds)

                for try await event in services.rag.streamAnswer(
                    context: context,
                    agent: effectiveAgent,
                    history: priorHistory
                ) {
                    try Task.checkCancellation()
                    if !connectStepFinished, Date() >= connectDeadline {
                        throw ChatPanelStreamError(
                            message: """
                            Timed out connecting to \(services.lmConfig.chatModelDisplay) after \
                            \(Int(AISafetyLimits.chatStreamTimeoutSeconds)) seconds. \
                            Start LM Studio (or your configured server) and load the chat model.
                            """
                        )
                    }
                    switch event.kind {
                    case .activity(let state):
                        if state != .idle {
                            services.setActivity(state)
                        }
                        if state == .streaming {
                            await finishConnectPipelineStep(
                                at: assistantIndex,
                                services: services,
                                connectStepFinished: &connectStepFinished
                            )
                            didEstablishStream = true
                        }
                    case .token(let token):
                        await finishConnectPipelineStep(
                            at: assistantIndex,
                            services: services,
                            connectStepFinished: &connectStepFinished
                        )
                        didEstablishStream = true
                        recordRespondFirstToken(at: assistantIndex)
                        services.setActivity(.streaming)
                        mutateMessage(at: assistantIndex) { message in
                            message.text += token
                        }
                    case .citations:
                        break
                    case .completed:
                        mutateMessage(at: assistantIndex) { message in
                            message.text = AIInput.stripChunkReferences(message.text)
                            message.isStreaming = false
                        }
                        await completeRespondStep(at: assistantIndex, skipDelay: false)
                        await completePipelineStep(at: assistantIndex, id: "done", skipDelay: true)
                        trimMessagesIfNeeded()
                        clearPipelineTimingState(for: assistantIndex)
                    case .error(let message):
                        await failConnectPipelineStep(
                            at: assistantIndex,
                            reason: message,
                            connectStepFinished: &connectStepFinished
                        )
                        services.markChatStreamFailed()
                        let diagnosed = await services.diagnoseChatFailure(
                            ChatPanelStreamError(message: message)
                        )
                        mutateMessage(at: assistantIndex) { assistant in
                            assistant.text = diagnosed
                            assistant.isError = true
                            assistant.isStreaming = false
                        }
                        markPipelineFailed(at: assistantIndex)
                        clearPipelineTimingState(for: assistantIndex)
                        services.setActivity(.idle)
                    }
                }

                if !connectStepFinished {
                    await failConnectPipelineStep(
                        at: assistantIndex,
                        reason: "Timed out after \(Int(AISafetyLimits.chatStreamTimeoutSeconds))s",
                        connectStepFinished: &connectStepFinished
                    )
                    let diagnosed = await services.diagnoseChatFailure(
                        ChatPanelStreamError(
                            message: """
                            Timed out connecting to \(services.lmConfig.chatModelDisplay). \
                            Start LM Studio and load the chat model, or change Chat model in Settings.
                            """
                        )
                    )
                    mutateMessage(at: assistantIndex) { message in
                        message.text = diagnosed
                        message.isError = true
                        message.isStreaming = false
                    }
                    markPipelineFailed(at: assistantIndex)
                    clearPipelineTimingState(for: assistantIndex)
                    services.markChatStreamFailed()
                    services.setActivity(.idle)
                    return
                }

                if assistantIndex < messages.count,
                   messages[assistantIndex].isStreaming {
                    mutateMessage(at: assistantIndex) { message in
                        message.isStreaming = false
                    }
                }
                if assistantIndex < messages.count,
                   messages[assistantIndex].pipelineSteps.contains(where: { $0.id == "respond" && $0.status == .active }) {
                    await completeRespondStep(at: assistantIndex, skipDelay: false)
                    await completePipelineStep(at: assistantIndex, id: "done", skipDelay: true)
                    trimMessagesIfNeeded()
                    clearPipelineTimingState(for: assistantIndex)
                }
                services.markChatStreamConnected()
                await services.confirmConnectionAfterStream()
            } catch is CancellationError {
                return
            } catch {
                let diagnosed = await services.diagnoseChatFailure(error)
                if assistantIndex < messages.count {
                    var connectDone = didEstablishStream
                    await failConnectPipelineStep(
                        at: assistantIndex,
                        reason: OpenWriteAIServices.shortChatFailureReason(error, config: services.lmConfig),
                        connectStepFinished: &connectDone
                    )
                    mutateMessage(at: assistantIndex) { message in
                        message.text = diagnosed
                        message.isError = true
                        message.isStreaming = false
                    }
                    markPipelineFailed(at: assistantIndex)
                    clearPipelineTimingState(for: assistantIndex)
                }
                services.markChatStreamFailed()
                services.setActivity(.idle)
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

    func importImageFromPasteboard() {
        attachmentError = nil
        if let fileURL = ImagePasteSupport.imageFileURLFromPasteboard() {
            let accessed = fileURL.startAccessingSecurityScopedResource()
            defer {
                if accessed { fileURL.stopAccessingSecurityScopedResource() }
            }
            do {
                let attachment = try ChatAttachmentStore.importFile(from: fileURL)
                pendingAttachments.append(attachment)
            } catch {
                attachmentError = error.localizedDescription
            }
            return
        }
        guard let image = ImagePasteSupport.imageFromPasteboard() else {
            attachmentError = "No image on the clipboard. Copy an image or use Attach file."
            return
        }
        do {
            let attachment = try ChatAttachmentStore.importPastedImage(image)
            pendingAttachments.append(attachment)
        } catch {
            attachmentError = error.localizedDescription
        }
    }

    func removePendingAttachment(id: UUID) {
        pendingAttachments.removeAll { $0.id == id }
    }

    func cancelSend(services: OpenWriteAIServices) {
        streamTask?.cancel()
        streamTask = nil
        if let index = messages.lastIndex(where: { $0.role == .assistant && $0.isStreaming }) {
            mutateMessage(at: index) { message in
                message.isStreaming = false
                if message.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    message.text = "Stopped."
                }
                for stepIndex in message.pipelineSteps.indices {
                    switch message.pipelineSteps[stepIndex].status {
                    case .active:
                        message.pipelineSteps[stepIndex].status = .failed
                    case .pending:
                        break
                    case .completed, .failed:
                        break
                    }
                }
                if let doneIndex = message.pipelineSteps.firstIndex(where: { $0.id == "done" }) {
                    message.pipelineSteps[doneIndex].title = "Stopped"
                    message.pipelineSteps[doneIndex].status = .completed
                }
            }
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
                let images = message.visionAttachments.filter { $0.kind == .image }
                let text = AIInput.sanitizeQuery(message.text)
                    ?? (images.isEmpty ? nil : "Review the attached files and answer my question.")
                guard let text else { continue }
                turns.append(
                    RAGConversationTurn(
                        role: .user,
                        text: text,
                        visionImageAttachments: images
                    )
                )
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

    /// Vault search with a hard cap so chat always reaches model connect / respond.
    private static func buildRAGContextWithTimeout(
        services: OpenWriteAIServices,
        query: String,
        agent: AgentConfig,
        attachments: [ChatAttachment],
        webPages: [WebPageSnapshot],
        searchesVault: Bool
    ) async throws -> (RAGContext, Bool) {
        do {
            if searchesVault {
                let context = try await AITaskTimeout.run(seconds: AISafetyLimits.vaultSearchTimeoutSeconds) {
                    try await services.rag.buildContext(
                        query: query,
                        agent: agent,
                        attachments: attachments,
                        webPages: webPages
                    )
                }
                return (context, false)
            }
            let context = try await services.rag.buildContext(
                query: query,
                agent: agent,
                attachments: attachments,
                webPages: webPages
            )
            return (context, false)
        } catch is CancellationError {
            throw CancellationError()
        } catch is AITaskTimeoutError {
            let sanitized = AIInput.sanitizeQuery(query) ?? query
            var hits: [RetrievalHit] = []
            if searchesVault, agent.toolFlags.useVaultRetrieval, agent.effectiveChunkLimit > 0 {
                hits = (try? await services.retrieval.keywordSearch(
                    query: sanitized,
                    limit: agent.effectiveChunkLimit
                )) ?? []
            }
            let fallback = RAGContext(
                query: sanitized,
                hits: hits,
                attachmentHits: ChatAttachmentStore.retrievalHits(from: attachments),
                webPages: webPages
            )
            return (fallback, true)
        } catch {
            throw error
        }
    }

    private static func initialPipelineSteps(searchesVault: Bool, fetchesWeb: Bool = false) -> [ChatPipelineStep] {
        var steps: [ChatPipelineStep] = []
        if fetchesWeb {
            steps.append(ChatPipelineStep(id: "web", title: "Fetching page…", status: .pending))
        }
        if searchesVault {
            steps.append(ChatPipelineStep(id: "search", title: "Searching vault…", status: .pending))
            steps.append(ChatPipelineStep(id: "sources", title: "Found sources", status: .pending))
        }
        steps.append(ChatPipelineStep(id: "connect", title: "Connecting to model…", status: .pending))
        steps.append(ChatPipelineStep(id: "respond", title: "Responding", status: .pending))
        steps.append(ChatPipelineStep(id: "done", title: "Done", status: .pending))
        return steps
    }

    /// Reassigns the message so `@Published` emits and the stepper refreshes during pre-stream phases.
    private func mutateMessage(at index: Int, _ body: (inout ChatMessage) -> Void) {
        guard index < messages.count else { return }
        var message = messages[index]
        body(&message)
        messages[index] = message
    }

    private func setPipelineStep(at index: Int, id: String, status: ChatPipelineStep.Status) {
        mutateMessage(at: index) { message in
            guard let stepIndex = message.pipelineSteps.firstIndex(where: { $0.id == id }) else { return }
            message.pipelineSteps[stepIndex].status = status
        }
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
        mutateMessage(at: index) { message in
            guard let stepIndex = message.pipelineSteps.firstIndex(where: { $0.id == id }) else { return }
            message.pipelineSteps[stepIndex].title = title
        }
    }

    /// Marks connect complete only after LM Studio HTTP stream delivers bytes (honest stepper).
    private func finishConnectPipelineStep(
        at index: Int,
        services: OpenWriteAIServices,
        connectStepFinished: inout Bool
    ) async {
        guard !connectStepFinished else { return }
        connectStepFinished = true
        updatePipelineStepTitle(
            at: index,
            id: "connect",
            title: AIActivityState.connecting.connectedStatus(
                modelDisplay: services.lmConfig.chatModelDisplay
            )
        )
        services.markChatStreamConnected()
        await services.confirmConnectionAfterStream()
        await completePipelineStep(at: index, id: "connect")
        activatePipelineStep(at: index, id: "respond")
    }

    private func failConnectPipelineStep(
        at index: Int,
        reason: String,
        connectStepFinished: inout Bool
    ) async {
        guard !connectStepFinished else { return }
        connectStepFinished = true
        let trimmed = reason.trimmingCharacters(in: .whitespacesAndNewlines)
        let title = trimmed.isEmpty ? "Connection failed" : "Connection failed — \(trimmed)"
        updatePipelineStepTitle(at: index, id: "connect", title: String(title.prefix(120)))
        setPipelineStep(at: index, id: "connect", status: .failed)
        mutateMessage(at: index) { message in
            for stepIndex in message.pipelineSteps.indices {
                let stepID = message.pipelineSteps[stepIndex].id
                guard stepID == "respond" || stepID == "done" else { continue }
                if message.pipelineSteps[stepIndex].status == .active {
                    message.pipelineSteps[stepIndex].status = .pending
                }
            }
        }
    }

    private func markPipelineFailed(at index: Int) {
        mutateMessage(at: index) { message in
            let connectFailed = message.pipelineSteps.contains { $0.id == "connect" && $0.status == .failed }
            for stepIndex in message.pipelineSteps.indices {
                let stepID = message.pipelineSteps[stepIndex].id
                switch message.pipelineSteps[stepIndex].status {
                case .active:
                    if connectFailed, stepID == "respond" || stepID == "done" {
                        message.pipelineSteps[stepIndex].status = .pending
                    } else {
                        message.pipelineSteps[stepIndex].status = .failed
                    }
                case .pending:
                    if connectFailed, stepID == "respond" || stepID == "done" {
                        continue
                    }
                    message.pipelineSteps[stepIndex].status = .failed
                case .completed, .failed:
                    break
                }
            }
            if !connectFailed, let doneIndex = message.pipelineSteps.firstIndex(where: { $0.id == "done" }) {
                message.pipelineSteps[doneIndex].title = "Failed"
                message.pipelineSteps[doneIndex].status = .failed
            }
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
                    OWBrandLogoSpinner(size: 20, periodSeconds: 1.9)
                        .scaleEffect(pulse ? 1.05 : 0.95)
                } else if case .error = state {
                    OWUnicodeIconView(icon: .warningFill, size: 16, color: DesignTokens.Color.warning)
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
    @State private var animationTask: Task<Void, Never>?

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
        .onDisappear {
            animationTask?.cancel()
            animationTask = nil
            phase = 0
        }
    }

    private func startCycle() {
        animationTask?.cancel()
        animationTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(320))
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Chat panel

struct ChatPanelView: View {
    @Environment(\.openWritePalette) private var palette
    @Environment(\.workbenchCenterLayout) private var workbenchLayout
    @Environment(ThemeManager.self) private var themeManager
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @EnvironmentObject private var workbench: WorkbenchState
    @StateObject private var model = ChatPanelModel()
    /// True when the transcript bottom sentinel is visible — auto-scroll only while pinned.
    @State private var chatPinnedToBottom = true
    /// Measured height of the bottom composer chrome (drives transcript scroll padding).
    @State private var measuredComposerHeight: CGFloat = 0

    private var navigation: AIAssistNavigationState { workbench.aiAssistNavigation }

    /// Assist strip owns top chrome at root; avoid duplicate headers and orphan icon rows.
    private var showsEmbeddedAssistStripChrome: Bool {
        navigation.isAtRoot
    }

    /// Composer sits in `safeAreaInset`; only a small slack gap is needed above it.
    private var transcriptBottomPadding: CGFloat {
        DesignTokens.Spacing.spacing3
    }

    var body: some View {
        let _ = themeManager.revision
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
            if !showsEmbeddedAssistStripChrome {
                OWAIPanelHeader(title: "Chat", compact: true)
            }
            OpenWriteThemedScrollView(canvasColor: palette.background) {
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
            .background(palette.background)
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
                        .foregroundStyle(isSelected ? DesignTokens.Color.accent : DesignTokens.Color.textPrimary)
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
                    ? DesignTokens.Color.accent.opacity(0.16)
                    : DesignTokens.Color.surface,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .strokeBorder(
                        isSelected ? DesignTokens.Color.accent.opacity(0.72) : DesignTokens.Color.borderSubtle.opacity(0.65),
                        lineWidth: isSelected ? 1.5 : DesignTokens.Layout.borderWidth
                    )
            }
        }
        .buttonStyle(.plain)
    .openWriteFocusChrome()
    }

    private var conversationPanel: some View {
        VStack(spacing: 0) {
            if !showsEmbeddedAssistStripChrome {
                conversationHeader
            }
            ChatTranscriptView(
                messages: model.messages,
                scrollToken: model.messages.chatScrollToken,
                bottomPadding: transcriptBottomPadding,
                background: palette.background,
                isPinnedToBottom: $chatPinnedToBottom
            )
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .clipped()
        .safeAreaInset(edge: .bottom, spacing: 0) {
            ChatComposerView(model: model, measuredHeight: $measuredComposerHeight)
        }
        .background(palette.background)
        .task {
            await aiServices.checkConnection()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            Task { await aiServices.checkConnection() }
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
                    AgentPickerView(selectedAgentID: $aiServices.selectedAgentID)
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

    private func agentHelp(_ agent: AgentConfig) -> String {
        agent.uiHelpText
    }
}
