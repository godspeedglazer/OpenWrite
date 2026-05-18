import Foundation

/// Reor-shaped tool capability flags (v1: retrieval; vault mutations are v2 stubs).
struct AgentToolFlags: Hashable, Sendable, Codable {
    /// Retrieve indexed vault chunks for the user query (Reor `search` tool / `retreiveFromVectorDB`).
    var useVaultRetrieval: Bool
    /// Future: propose a new note after explicit user confirmation (Reor `createNote`).
    var allowCreateNote: Bool
    /// Future: read/list vault files with confirmation (Reor `readFile`, `listFiles`).
    var allowReadFiles: Bool
    /// Prefer wider note excerpts when chunks are assembled (Reor `passFullNoteIntoContext`).
    var passFullNoteContext: Bool

    static let retrievalOnly = AgentToolFlags(
        useVaultRetrieval: true,
        allowCreateNote: false,
        allowReadFiles: false,
        passFullNoteContext: false
    )

    static let retrievalWithFullNote = AgentToolFlags(
        useVaultRetrieval: true,
        allowCreateNote: false,
        allowReadFiles: false,
        passFullNoteContext: true
    )
}

/// Local agent template: system instructions, retrieval budget, and tool flags.
struct AgentConfig: Identifiable, Hashable, Sendable, Codable {
    let id: String
    var name: String
    var systemPrompt: String
    /// Max indexed chunks to retrieve (Reor `dbSearchFilters.limit`).
    var chunkLimit: Int
    var toolFlags: AgentToolFlags
    /// LM Studio sampling temperature for this preset.
    var temperature: Double
    /// Max distinct source excerpts in the system prompt (one chunk per document).
    var maxReferenceExcerpts: Int
    /// Per-chunk excerpt character cap (overrides `passFullNoteContext` default when set).
    var snippetMaxChars: Int?
    /// Short picker / tooltip copy (not sent to the model).
    var uiSummary: String
    /// Extra system instructions appended after excerpts (agent-specific answer shape).
    var answerInstructions: String

    var effectiveChunkLimit: Int {
        guard chunkLimit > 0 else { return 0 }
        return min(chunkLimit, AISafetyLimits.maxContextChunks)
    }

    var effectiveMaxReferenceExcerpts: Int {
        min(maxReferenceExcerpts, effectiveChunkLimit, AISafetyLimits.maxChatReferenceExcerpts)
    }

    /// Tooltip / picker subtitle (not sent to the model).
    var uiHelpText: String {
        uiSummary
    }

    var snippetCharsPerChunk: Int {
        if let snippetMaxChars {
            return min(snippetMaxChars, AISafetyLimits.maxSnippetCharsPerChunk * 2)
        }
        return toolFlags.passFullNoteContext
            ? min(800, AISafetyLimits.maxSnippetCharsPerChunk * 2)
            : AISafetyLimits.maxSnippetCharsPerChunk
    }

    func withVaultRetrieval(_ enabled: Bool) -> AgentConfig {
        var copy = self
        copy.toolFlags.useVaultRetrieval = enabled
        return copy
    }
}
