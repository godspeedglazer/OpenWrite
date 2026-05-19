import Foundation

/// Hard caps for local RAG and LM Studio payloads (rem `AISearchLimits`-style).
enum AISafetyLimits {
    static let maxQueryCharacters = 500
    static let maxChatMessageCharacters = 2000
    static let prefilterCandidateCount = 32
    static let rerankCandidateCount = 24
    /// Upper bound for per-agent `chunkLimit` (summarizer may request more than Q&A).
    static let maxContextChunks = 20
    /// Hard cap on distinct source excerpts in chat system context (safety budget).
    static let maxChatReferenceExcerpts = 10
    static let maxSnippetCharsPerChunk = 400
    static let maxEstimatedPromptTokens = 3000
    static let charsPerTokenEstimate = 4
    static let systemPromptReservedTokens = 320
    static let maxCompletionTokens = 1024
    static let searchDebounceSeconds: TimeInterval = 0.35
    static let inlineSelectionDebounceSeconds: TimeInterval = 0.12
    static let maxInlineSelectionChars = 1500
    static let maxInlineRefineContextChunks = 4
    static let maxInlineRefinePromptTokens = 2000
    static let hybridVectorWeight = 0.7
    /// Extra keyword weight for title / filename / title-lead chunk matches.
    static let titleKeywordBoostMultiplier = 2.5
    /// Added to fused score when query is temporal and chunk has a recent `documentUpdatedAt`.
    static let recencyBoostWeight = 0.12
    /// Max chunks returned per document after hybrid fusion.
    static let maxChunksPerDocumentInResults = 2
    /// Reor default `chunkSize` (store migrator); heading groups larger than this are split recursively.
    static let indexChunkMaxChars = 1000
    /// ~15% overlap for recursive splits and cross-section bridges.
    static let indexChunkOverlap = 150
    static let embeddingDimensions = 384
    static let maxEmbeddingInputChars = 2000

    /// Safe web lookup (server-side fetch in app, not in-page JS).
    static let maxWebFetchBytes = 512 * 1024
    static let webFetchTimeoutSeconds: TimeInterval = 10
    /// Query-time vault embedding call; falls back to local hash vectors on timeout.
    static let retrievalEmbeddingTimeoutSeconds: TimeInterval = 3
    /// Indexing / bulk embed attempts against LM Studio (fast-fail before local hash fallback).
    static let indexingEmbeddingTimeoutSeconds: TimeInterval = 3
    /// After connection refused, skip remote embeds for this window to avoid log/CPU storms.
    static let embeddingCircuitCooldownSeconds: TimeInterval = 120
    /// Minimum spacing for a single in-app “LM Studio unreachable” notice.
    static let embeddingUnreachableNoticeIntervalSeconds: TimeInterval = 90
    /// Whole note-index search phase in chat (embed + vector scan); then chat continues with no hits.
    static let vaultSearchTimeoutSeconds: TimeInterval = 15
    /// Chat HTTP connect + first streamed token; fails connect step when LM Studio is down.
    static let chatStreamTimeoutSeconds: TimeInterval = 30
    static let webFetchMaxRedirects = 3
    /// Single-pass web lookup (default chat).
    static let maxWebURLsPerMessage = 2
    /// Multi-hop research pass (Research Q&A + Web on).
    static let maxWebURLsPerResearchPass = 5
    static let maxWebResearchPasses = 2
    static let maxWebChunksPerPage = 4
    static let maxWebChunkChars = 900
    static let maxWebTextChars = 12_000
    /// Per-image cap for vision chat payloads (base64 in LM Studio / OpenAI-compatible API).
    static let maxVisionImageBytes = 4 * 1024 * 1024
    static let maxVisionImagesPerMessage = 4
    /// How many prior user turns may still include image payloads in chat history.
    static let maxVisionHistoryUserTurns = 2
}

enum AITaskTimeoutError: Error, Sendable {
    case timedOut(TimeInterval)
}

/// Races an async operation against a sleep; cancels the loser.
enum AITaskTimeout {
    static func run<T: Sendable>(
        seconds: TimeInterval,
        operation: @Sendable @escaping () async throws -> T
    ) async throws -> T {
        try await withThrowingTaskGroup(of: T.self) { group in
            group.addTask { try await operation() }
            group.addTask {
                try await Task.sleep(for: .seconds(seconds))
                throw AITaskTimeoutError.timedOut(seconds)
            }
            guard let result = try await group.next() else {
                throw AITaskTimeoutError.timedOut(seconds)
            }
            group.cancelAll()
            return result
        }
    }
}

enum AIInput {
    private static let controlCharacterSet = CharacterSet.controlCharacters
        .union(CharacterSet(charactersIn: "\u{FFFE}\u{FFFF}"))

    static func sanitizeQuery(_ raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let stripped = String(trimmed.unicodeScalars.filter { !controlCharacterSet.contains($0) })
        let collapsed = stripped.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !collapsed.isEmpty else { return nil }
        if collapsed.count <= AISafetyLimits.maxQueryCharacters {
            return collapsed
        }
        return String(collapsed.prefix(AISafetyLimits.maxQueryCharacters))
    }

    static func sanitizeSnippet(_ text: String, maxChars: Int) -> String {
        let stripped = String(text.unicodeScalars.filter { !controlCharacterSet.contains($0) })
        let collapsed = stripped.split(separator: "\n").joined(separator: " ")
        if collapsed.count <= maxChars { return collapsed }
        return String(collapsed.prefix(max(0, maxChars - 3))) + "..."
    }

    static func estimatedTokenCount(for text: String) -> Int {
        max(1, (text.count + AISafetyLimits.charsPerTokenEstimate - 1) / AISafetyLimits.charsPerTokenEstimate)
    }

    /// Removes model citation markers from text shown in the chat UI (including partial stream tokens).
    static func stripChunkReferences(_ text: String) -> String {
        let patterns = [
            #"\[chunk:\s*[^\]]*\]?"#,
            #"\[chunk:[^\]\n]*"#,
            #"\[web:\s*[^\]]*\]?"#,
            #"\[web:[^\]\n]*"#,
            #"\bchunk:\s*[0-9a-fA-F-]{8,}(?:-[0-9a-fA-F-]+)*\b"#
        ]
        var result = text
        for pattern in patterns {
            guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
                continue
            }
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(in: result, range: range, withTemplate: "")
        }
        for partial in [#"\[chunk:[^\]]*$"#, #"\[web:[^\]]*$"#] {
            if let trailing = try? NSRegularExpression(pattern: partial, options: [.caseInsensitive]),
               let match = trailing.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
               let range = Range(match.range, in: result) {
                result.removeSubrange(range)
            }
        }
        return result
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
