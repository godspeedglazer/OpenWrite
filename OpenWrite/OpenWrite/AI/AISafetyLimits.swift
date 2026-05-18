import Foundation

/// Hard caps for local RAG and LM Studio payloads (rem `AISearchLimits`-style).
enum AISafetyLimits {
    static let maxQueryCharacters = 500
    static let maxChatMessageCharacters = 2000
    static let prefilterCandidateCount = 32
    static let rerankCandidateCount = 24
    static let maxContextChunks = 12
    /// Hard cap on vault excerpts in chat system context (reduces RAG dominance).
    static let maxChatReferenceExcerpts = 6
    static let maxSnippetCharsPerChunk = 400
    static let maxEstimatedPromptTokens = 3000
    static let charsPerTokenEstimate = 4
    static let systemPromptReservedTokens = 320
    static let maxCompletionTokens = 1024
    static let searchDebounceSeconds: TimeInterval = 0.35
    static let inlineSelectionDebounceSeconds: TimeInterval = 0.4
    static let maxInlineSelectionChars = 1500
    static let maxInlineRefineContextChunks = 4
    static let maxInlineRefinePromptTokens = 2000
    static let hybridVectorWeight = 0.7
    /// Reor default `chunkSize` (store migrator); heading groups larger than this are split recursively.
    static let indexChunkMaxChars = 1000
    /// Reor `chunkMarkdownByHeadingsAndByCharsIfBig` overlap.
    static let indexChunkOverlap = 20
    static let embeddingDimensions = 384
    static let maxEmbeddingInputChars = 2000

    /// Safe web lookup (server-side fetch in app, not in-page JS).
    static let maxWebFetchBytes = 512 * 1024
    static let webFetchTimeoutSeconds: TimeInterval = 10
    static let webFetchMaxRedirects = 3
    static let maxWebURLsPerMessage = 2
    static let maxWebTextChars = 12_000
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
        if let trailing = try? NSRegularExpression(pattern: #"\[chunk:[^\]]*$"#, options: [.caseInsensitive]),
           let match = trailing.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
           let range = Range(match.range, in: result) {
            result.removeSubrange(range)
        }
        return result
            .replacingOccurrences(of: #"[ \t]{2,}"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\n{3,}"#, with: "\n\n", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
