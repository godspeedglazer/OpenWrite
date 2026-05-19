import Foundation

struct RAGContext: Sendable {
    var query: String
    var hits: [RetrievalHit]
    var attachmentHits: [RetrievalHit] = []
    /// Image files attached in chat — encoded as `image_url` parts for vision models (e.g. Gemma 4).
    var visionImageAttachments: [ChatAttachment] = []
    /// Server-fetched page text (safe web lookup); injected into system context, not indexed.
    var webPages: [WebPageSnapshot] = []

    var allHits: [RetrievalHit] {
        hits + attachmentHits
    }
}

/// Prior user/assistant turns sent to LM Studio (RAG excerpts stay in system).
struct RAGConversationTurn: Sendable {
    enum Role: String, Sendable {
        case user
        case assistant
    }

    let role: Role
    let text: String
    /// Images the user attached on this turn (re-sent in history for vision models).
    var visionImageAttachments: [ChatAttachment] = []
}

struct RAGStreamEvent: Sendable {
    enum Kind: Sendable {
        case activity(AIActivityState)
        case token(String)
        case citations([UUID])
        case completed
        case error(String)
    }

    var kind: Kind
}

struct RAGAnswer: Sendable {
    var text: String
    var citationChunkIDs: [UUID]
    var hits: [RetrievalHit]
}

/// Retrieval-augmented generation over the local vault.
protocol RAGService: Sendable {
    func buildContext(
        query: String,
        agent: AgentConfig,
        attachments: [ChatAttachment],
        webPages: [WebPageSnapshot]
    ) async throws -> RAGContext
    func streamAnswer(
        context: RAGContext,
        agent: AgentConfig,
        history: [RAGConversationTurn]
    ) -> AsyncThrowingStream<RAGStreamEvent, Error>
    func answer(
        query: String,
        agent: AgentConfig,
        attachments: [ChatAttachment],
        history: [RAGConversationTurn]
    ) async throws -> RAGAnswer
}

extension RAGService {
    func buildContext(query: String, agent: AgentConfig) async throws -> RAGContext {
        try await buildContext(query: query, agent: agent, attachments: [], webPages: [])
    }

    func buildContext(
        query: String,
        agent: AgentConfig,
        attachments: [ChatAttachment]
    ) async throws -> RAGContext {
        try await buildContext(query: query, agent: agent, attachments: attachments, webPages: [])
    }

    func streamAnswer(context: RAGContext, agent: AgentConfig) -> AsyncThrowingStream<RAGStreamEvent, Error> {
        streamAnswer(context: context, agent: agent, history: [])
    }

    func answer(query: String, agent: AgentConfig) async throws -> RAGAnswer {
        try await answer(query: query, agent: agent, attachments: [], history: [])
    }

    func answer(
        query: String,
        agent: AgentConfig,
        attachments: [ChatAttachment]
    ) async throws -> RAGAnswer {
        try await answer(query: query, agent: agent, attachments: attachments, history: [])
    }
}

struct LiveRAGService: RAGService {
    let retrieval: RetrievalService
    let client: LMStudioClient

    func buildContext(
        query: String,
        agent: AgentConfig,
        attachments: [ChatAttachment] = [],
        webPages: [WebPageSnapshot] = []
    ) async throws -> RAGContext {
        let visionImages = attachments.filter { $0.kind == .image }
        guard let sanitized = AIInput.sanitizeQuery(query) else {
            return RAGContext(
                query: query,
                hits: [],
                attachmentHits: ChatAttachmentStore.retrievalHits(from: attachments),
                visionImageAttachments: visionImages,
                webPages: webPages
            )
        }
        let attachmentHits = ChatAttachmentStore.retrievalHits(from: attachments)
        let limit = agent.toolFlags.useVaultRetrieval ? agent.effectiveChunkLimit : 0
        guard limit > 0 else {
            return RAGContext(
                query: sanitized,
                hits: [],
                attachmentHits: attachmentHits,
                visionImageAttachments: visionImages,
                webPages: webPages
            )
        }
        let hits = try await retrieval.search(
            query: sanitized,
            limit: limit
        )
        return RAGContext(
            query: sanitized,
            hits: hits,
            attachmentHits: attachmentHits,
            visionImageAttachments: visionImages,
            webPages: webPages
        )
    }

    func streamAnswer(
        context: RAGContext,
        agent: AgentConfig,
        history: [RAGConversationTurn] = []
    ) -> AsyncThrowingStream<RAGStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (systemContent, citationIDs) = Self.systemAndCitations(context: context, agent: agent)
                    var messages: [[String: Any]] = [
                        ["role": "system", "content": systemContent]
                    ]
                    messages.append(contentsOf: Self.historyPayload(history))
                    let userContent = ChatVisionPayload.userMessageContent(
                        text: Self.userMessageContent(query: context.query),
                        imageAttachments: context.visionImageAttachments
                    )
                    messages.append(["role": "user", "content": userContent])

                    // `.connecting` until HTTP stream delivers bytes — UI must not mark "Connected" before this.
                    continuation.yield(RAGStreamEvent(kind: .activity(.connecting)))
                    continuation.yield(RAGStreamEvent(kind: .citations(citationIDs)))

                    var fullText = ""
                    var announcedFirstToken = false
                    for try await delta in client.chatCompletionsStream(
                        messages: messages,
                        temperature: agent.temperature
                    ) {
                        if !announcedFirstToken {
                            announcedFirstToken = true
                            continuation.yield(RAGStreamEvent(kind: .activity(.streaming)))
                        }
                        fullText += delta
                        continuation.yield(RAGStreamEvent(kind: .token(delta)))
                    }

                    let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        continuation.yield(RAGStreamEvent(kind: .error(Self.emptyCompletionUserMessage)))
                    } else {
                        continuation.yield(RAGStreamEvent(kind: .completed))
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(RAGStreamEvent(kind: .error(Self.streamErrorUserMessage(error))))
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func answer(
        query: String,
        agent: AgentConfig,
        attachments: [ChatAttachment] = [],
        history: [RAGConversationTurn] = []
    ) async throws -> RAGAnswer {
        let context = try await buildContext(query: query, agent: agent, attachments: attachments)
        var text = ""
        var citationIDs: [UUID] = []

        for try await event in streamAnswer(context: context, agent: agent, history: history) {
            switch event.kind {
            case .token(let token):
                text += token
            case .citations(let ids):
                citationIDs = ids
            case .error(let message):
                throw LMStudioError.httpStatus(0, message)
            case .completed, .activity:
                break
            }
        }

        return RAGAnswer(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            citationChunkIDs: citationIDs,
            hits: context.allHits
        )
    }

    private static let emptyCompletionUserMessage = "The chat model returned an empty reply."

    private static func streamErrorUserMessage(_ error: Error) -> String {
        if let lm = error as? LMStudioError, case .emptyResponse = lm {
            return emptyCompletionUserMessage
        }
        let detail = (error as? LocalizedError)?.errorDescription ?? error.localizedDescription
        return String(detail.prefix(240))
    }

    private static func historyPayload(_ history: [RAGConversationTurn]) -> [[String: Any]] {
        let recentVisionTurnIndexes = Set(
            history.enumerated().compactMap { index, turn -> Int? in
                turn.role == .user && !turn.visionImageAttachments.isEmpty ? index : nil
            }.suffix(AISafetyLimits.maxVisionHistoryUserTurns)
        )

        return history.enumerated().compactMap { index, turn in
            let trimmed = turn.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return nil }
            let capped = trimmed.count <= AISafetyLimits.maxChatMessageCharacters
                ? trimmed
                : String(trimmed.prefix(AISafetyLimits.maxChatMessageCharacters))

            let content: Any
            if turn.role == .user,
               recentVisionTurnIndexes.contains(index),
               !turn.visionImageAttachments.isEmpty {
                content = ChatVisionPayload.userMessageContent(
                    text: capped,
                    imageAttachments: turn.visionImageAttachments
                )
            } else {
                content = capped
            }
            return ["role": turn.role.rawValue, "content": content]
        }
    }

    private static func userMessageContent(query: String) -> String {
        """
        User question:
        \(query)
        """
    }

    private static func systemAndCitations(context: RAGContext, agent: AgentConfig) -> (String, [UUID]) {
        let (excerptBlock, ids) = excerptBlock(context: context, agent: agent)
        var parts = [agent.systemPrompt]
        if !agent.answerInstructions.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            parts.append("")
            parts.append(agent.answerInstructions)
        }
        if !excerptBlock.isEmpty {
            parts.append("")
            parts.append(excerptBlock)
        }
        if !context.webPages.isEmpty {
            parts.append("")
            parts.append(webExcerptBlock(pages: context.webPages))
        }
        if !context.visionImageAttachments.isEmpty {
            parts.append("")
            parts.append(
                """
                The user's message includes \(context.visionImageAttachments.count) image(s) \
                attached for visual analysis. Describe what you see when it helps answer the question.
                """
            )
        }
        return (parts.joined(separator: "\n"), ids)
    }

    private static func webExcerptBlock(pages: [WebPageSnapshot]) -> String {
        var lines = [
            "Web pages fetched for this turn (supporting evidence only; cite URLs when used):",
            ""
        ]
        var usedTokens = AISafetyLimits.systemPromptReservedTokens
        for (index, page) in pages.enumerated() {
            let titleLine = page.title.map { " — \($0)" } ?? ""
            let header = "\(index + 1). \(page.finalURL.absoluteString)\(titleLine)"
            let body = AIInput.sanitizeSnippet(page.text, maxChars: AISafetyLimits.maxWebTextChars / max(1, pages.count))
            let block = "\(header)\n\(body)"
            let blockTokens = AIInput.estimatedTokenCount(for: block)
            if usedTokens + blockTokens > AISafetyLimits.maxEstimatedPromptTokens { break }
            usedTokens += blockTokens
            lines.append(block)
        }
        return lines.joined(separator: "\n\n")
    }

    private static func excerptBlock(context: RAGContext, agent: AgentConfig) -> (String, [UUID]) {
        var lines: [String] = [
            "Reference excerpts (supporting evidence only; optional):",
            ""
        ]
        var ids: [UUID] = []
        var usedTokens = AISafetyLimits.systemPromptReservedTokens
        let maxSnippet = agent.snippetCharsPerChunk
        let excerptCap = effectiveExcerptCap(context: context, agent: agent)
        let hitsForExcerpt = dedupedHitsForExcerpt(context: context, cap: excerptCap)

        var blockIndex = 0
        for hit in hitsForExcerpt {
            let header = "[chunk:\(hit.id.uuidString)] \(hit.sourcePillTitle)"
            let body = AIInput.sanitizeSnippet(hit.snippet, maxChars: maxSnippet)
            blockIndex += 1
            let block = "\(blockIndex). \(header)\n\(body)"
            let blockTokens = AIInput.estimatedTokenCount(for: block)
            if usedTokens + blockTokens > AISafetyLimits.maxEstimatedPromptTokens { break }
            usedTokens += blockTokens
            lines.append(block)
            ids.append(hit.id)
        }

        if ids.isEmpty {
            lines.append("(No matching notes in the local index.)")
        }

        return (lines.joined(separator: "\n\n"), ids)
    }

    /// One chunk per vault document (drops duplicate Welcome vs Welcome.md index rows).
    private static func dedupedHitsForExcerpt(context: RAGContext, cap: Int) -> [RetrievalHit] {
        context.allHits.uniqueDocumentSources(limit: max(1, cap))
    }

    private static func effectiveExcerptCap(context: RAGContext, agent: AgentConfig) -> Int {
        let base = agent.effectiveMaxReferenceExcerpts
        guard agent.id == AgentRegistry.researchQA.id,
              !context.allHits.isEmpty,
              queryLooksOffVaultTopic(query: context.query, hits: context.allHits) else {
            return base
        }
        return min(base, 3)
    }

    private static func queryLooksOffVaultTopic(query: String, hits: [RetrievalHit]) -> Bool {
        let terms = significantQueryTerms(query)
        guard terms.count >= 2 else { return false }
        let corpus = hits.prefix(8).map(\.snippet).joined(separator: " ").lowercased()
        let matched = terms.filter { corpus.contains($0) }.count
        return Double(matched) / Double(terms.count) < 0.25
    }

    private static func significantQueryTerms(_ query: String) -> [String] {
        let stop: Set<String> = [
            "a", "an", "the", "and", "or", "but", "in", "on", "at", "to", "for", "of", "with",
            "is", "are", "was", "were", "be", "been", "being", "have", "has", "had", "do", "does",
            "did", "will", "would", "could", "should", "may", "might", "must", "shall", "can",
            "this", "that", "these", "those", "it", "its", "i", "me", "my", "we", "our", "you",
            "your", "how", "what", "when", "where", "why", "who", "which", "app", "openwrite",
            "help", "use", "using", "notes", "note", "take", "taking"
        ]
        return query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 && !stop.contains($0) }
    }
}

struct PlaceholderRAGService: RAGService {
    let retrieval: RetrievalService

    func buildContext(
        query: String,
        agent: AgentConfig,
        attachments: [ChatAttachment] = [],
        webPages: [WebPageSnapshot] = []
    ) async throws -> RAGContext {
        let limit = agent.toolFlags.useVaultRetrieval ? agent.effectiveChunkLimit : 0
        let hits = limit > 0
            ? try await retrieval.search(query: query, limit: limit)
            : []
        return RAGContext(
            query: query,
            hits: hits,
            attachmentHits: ChatAttachmentStore.retrievalHits(from: attachments),
            visionImageAttachments: attachments.filter { $0.kind == .image },
            webPages: webPages
        )
    }

    func streamAnswer(
        context: RAGContext,
        agent: AgentConfig,
        history: [RAGConversationTurn] = []
    ) -> AsyncThrowingStream<RAGStreamEvent, Error> {
        _ = history
        _ = agent
        return AsyncThrowingStream { continuation in
            continuation.yield(RAGStreamEvent(kind: .activity(.connecting)))
            continuation.yield(RAGStreamEvent(kind: .citations(context.hits.map(\.id))))
            continuation.yield(RAGStreamEvent(kind: .activity(.streaming)))
            continuation.yield(RAGStreamEvent(kind: .token("Index-only mode — connect LM Studio for answers.")))
            continuation.yield(RAGStreamEvent(kind: .completed))
            continuation.finish()
        }
    }

    func answer(
        query: String,
        agent: AgentConfig,
        attachments: [ChatAttachment] = [],
        history: [RAGConversationTurn] = []
    ) async throws -> RAGAnswer {
        _ = history
        let context = try await buildContext(query: query, agent: agent, attachments: attachments)
        return RAGAnswer(text: "", citationChunkIDs: context.allHits.map(\.id), hits: context.allHits)
    }
}
