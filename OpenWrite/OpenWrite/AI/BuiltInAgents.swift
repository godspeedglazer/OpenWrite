import Foundation

/// Built-in chat agents (clean-room; behavior inspired by Reor example agents, not copied).
enum BuiltInAgents {
    static let defaultAgent = researchQA

    static let all: [AgentConfig] = [
        researchQA,
        summarizeSelection,
        refineProse
    ]

    static func agent(id: String) -> AgentConfig {
        agentsByID[id] ?? researchQA
    }

    private static let agentsByID: [String: AgentConfig] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    static let researchQA = AgentConfig(
        id: "research-qa",
        name: "Research Q&A",
        systemPrompt: """
        You are OpenWrite, a local-first research assistant. Answer the user's question using ONLY the provided note excerpts.
        Cite sources using bracket IDs exactly as given, e.g. [chunk:UUID]. If context is insufficient, say so briefly.
        Respond in the same language as the user's question. Be concise, factual, and do not invent note content.
        """,
        chunkLimit: 12,
        toolFlags: .retrievalOnly
    )

    static let summarizeSelection = AgentConfig(
        id: "summarize-selection",
        name: "Summarize selection",
        systemPrompt: """
        You summarize material from the user's notes. Use ONLY the provided excerpts.
        Produce a tight summary: key points as short bullets or one short paragraph. No preamble.
        Cite [chunk:UUID] when a point comes from a specific excerpt. Do not invent content.
        Match the user's language.
        """,
        chunkLimit: 8,
        toolFlags: .retrievalWithFullNote
    )

    static let refineProse = AgentConfig(
        id: "refine-prose",
        name: "Refine prose",
        systemPrompt: """
        You help refine the user's writing using their notes as reference when relevant.
        When excerpts are provided, ground suggestions in them and cite [chunk:UUID] when referencing a note.
        Improve clarity, flow, and grammar while preserving the author's intent and voice.
        If the user asks to rewrite text they pasted in the question, focus on that text; do not fabricate vault facts.
        Return only the improved text unless they ask for commentary.
        """,
        chunkLimit: 6,
        toolFlags: .retrievalOnly
    )
}
