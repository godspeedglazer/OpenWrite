import Foundation

/// Hard caps for local RAG and LM Studio payloads (rem `AISearchLimits`-style).
enum AISafetyLimits {
    static let maxQueryCharacters = 500
    static let maxChatMessageCharacters = 2000
    static let prefilterCandidateCount = 32
    static let rerankCandidateCount = 24
    static let maxContextChunks = 12
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
    static let embeddingDimensions = 384
    static let maxEmbeddingInputChars = 2000
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
}
