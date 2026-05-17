import Foundation

/// Reor-shaped tool capability flags (v1: retrieval only; create-note is a v2 stub).
struct AgentToolFlags: Hashable, Sendable, Codable {
    /// Retrieve indexed vault chunks for the user query.
    var useVaultRetrieval: Bool
    /// Future: propose a new note after explicit user confirmation.
    var allowCreateNote: Bool
    /// Prefer wider note excerpts when chunks are assembled (Reor `passFullNoteIntoContext`).
    var passFullNoteContext: Bool

    static let retrievalOnly = AgentToolFlags(
        useVaultRetrieval: true,
        allowCreateNote: false,
        passFullNoteContext: false
    )

    static let retrievalWithFullNote = AgentToolFlags(
        useVaultRetrieval: true,
        allowCreateNote: false,
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

    var effectiveChunkLimit: Int {
        min(max(1, chunkLimit), AISafetyLimits.maxContextChunks)
    }

    var snippetCharsPerChunk: Int {
        toolFlags.passFullNoteContext
            ? min(800, AISafetyLimits.maxSnippetCharsPerChunk * 2)
            : AISafetyLimits.maxSnippetCharsPerChunk
    }
}
