import Foundation

struct RAGContext: Sendable {
    var query: String
    var hits: [RetrievalHit]
}

struct RAGStreamEvent: Sendable {
    enum Kind: Sendable {
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
    func buildContext(query: String, limit: Int) async throws -> RAGContext
    func streamAnswer(context: RAGContext) -> AsyncThrowingStream<RAGStreamEvent, Error>
    func answer(query: String, limit: Int) async throws -> RAGAnswer
}

struct LiveRAGService: RAGService {
    let retrieval: RetrievalService
    let client: LMStudioClient

    private static let systemPrompt = """
    You are OpenWrite, a local-first writing assistant. Answer using ONLY the provided note excerpts.
    Cite sources using bracket IDs exactly as given, e.g. [chunk:UUID]. If context is insufficient, say so briefly.
    Be concise and factual. Do not invent note content.
    """

    func buildContext(query: String, limit: Int) async throws -> RAGContext {
        guard let sanitized = AIInput.sanitizeQuery(query) else {
            return RAGContext(query: query, hits: [])
        }
        let hits = try await retrieval.search(
            query: sanitized,
            limit: min(limit, AISafetyLimits.maxContextChunks)
        )
        return RAGContext(query: sanitized, hits: hits)
    }

    func streamAnswer(context: RAGContext) -> AsyncThrowingStream<RAGStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    let (userMessage, citationIDs) = Self.promptPayload(context: context)
                    let messages: [[String: String]] = [
                        ["role": "system", "content": Self.systemPrompt],
                        ["role": "user", "content": userMessage]
                    ]

                    continuation.yield(RAGStreamEvent(kind: .citations(citationIDs)))

                    var fullText = ""
                    for try await delta in client.chatCompletionsStream(messages: messages) {
                        fullText += delta
                        continuation.yield(RAGStreamEvent(kind: .token(delta)))
                    }

                    let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        continuation.yield(RAGStreamEvent(kind: .error("Empty response from LM Studio")))
                    } else {
                        continuation.yield(RAGStreamEvent(kind: .completed))
                    }
                    continuation.finish()
                } catch {
                    continuation.yield(RAGStreamEvent(kind: .error(error.localizedDescription)))
                    continuation.finish()
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    func answer(query: String, limit: Int) async throws -> RAGAnswer {
        let context = try await buildContext(query: query, limit: limit)
        var text = ""
        var citationIDs: [UUID] = []

        for try await event in streamAnswer(context: context) {
            switch event.kind {
            case .token(let token):
                text += token
            case .citations(let ids):
                citationIDs = ids
            case .error(let message):
                throw LMStudioError.httpStatus(0, message)
            case .completed:
                break
            }
        }

        return RAGAnswer(
            text: text.trimmingCharacters(in: .whitespacesAndNewlines),
            citationChunkIDs: citationIDs,
            hits: context.hits
        )
    }

    private static func promptPayload(context: RAGContext) -> (String, [UUID]) {
        var lines: [String] = ["Question: \(context.query)", "", "Note excerpts:"]
        var ids: [UUID] = []
        var usedTokens = AIInput.estimatedTokenCount(for: context.query) + AISafetyLimits.systemPromptReservedTokens

        for (index, hit) in context.hits.enumerated() {
            let header = "[chunk:\(hit.id.uuidString)] \(hit.documentTitle)"
            let body = AIInput.sanitizeSnippet(hit.snippet, maxChars: AISafetyLimits.maxSnippetCharsPerChunk)
            let block = "\(index + 1). \(header)\n\(body)"
            let blockTokens = AIInput.estimatedTokenCount(for: block)
            if usedTokens + blockTokens > AISafetyLimits.maxEstimatedPromptTokens { break }
            usedTokens += blockTokens
            lines.append(block)
            ids.append(hit.id)
        }

        if context.hits.isEmpty {
            lines.append("(No matching notes in the local index.)")
        }

        return (lines.joined(separator: "\n\n"), ids)
    }
}

struct PlaceholderRAGService: RAGService {
    let retrieval: RetrievalService

    func buildContext(query: String, limit: Int) async throws -> RAGContext {
        let hits = try await retrieval.search(query: query, limit: limit)
        return RAGContext(query: query, hits: hits)
    }

    func streamAnswer(context: RAGContext) -> AsyncThrowingStream<RAGStreamEvent, Error> {
        AsyncThrowingStream { continuation in
            continuation.yield(RAGStreamEvent(kind: .citations(context.hits.map(\.id))))
            continuation.yield(RAGStreamEvent(kind: .token("Index-only mode — connect LM Studio for answers.")))
            continuation.yield(RAGStreamEvent(kind: .completed))
            continuation.finish()
        }
    }

    func answer(query: String, limit: Int) async throws -> RAGAnswer {
        let context = try await buildContext(query: query, limit: limit)
        return RAGAnswer(text: "", citationChunkIDs: context.hits.map(\.id), hits: context.hits)
    }
}
