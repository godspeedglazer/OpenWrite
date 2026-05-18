// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Agent and tool metadata adapted from Reor (https://github.com/reorproject/reor)
// `src/lib/llm/tools/tool-definitions.ts`. Swift types only; handlers are OpenWrite-native.
// See OpenWrite/AI/ReorPortNotes.md for AGPL scope and v2 tool wiring.

import Foundation

/// Reor `ToolDefinition.parameters[]` entry shape.
struct AgentToolParameter: Hashable, Sendable, Codable {
    var name: String
    var type: String
    var description: String
    var optional: Bool
    var defaultValue: String?

    init(
        name: String,
        type: String,
        description: String,
        optional: Bool = false,
        defaultValue: String? = nil
    ) {
        self.name = name
        self.type = type
        self.description = description
        self.optional = optional
        self.defaultValue = defaultValue
    }
}

/// Reor `ToolDefinition` — schema for future LM tool-calling (v1 uses flags on `AgentConfig`).
struct AgentToolDefinition: Identifiable, Hashable, Sendable, Codable {
    var id: String { name }
    let name: String
    let displayName: String
    let description: String
    let parameters: [AgentToolParameter]
    /// Reor `autoExecute` (e.g. search runs without extra confirmation).
    let autoExecute: Bool
}

enum AgentRegistry {
    static let defaultAgent = researchQA

    /// Chat picker agents (excludes editor-only presets).
    static let pickerAgents: [AgentConfig] = [
        researchQA,
        noteSummarizer,
        outlineHelper
    ]

    static let all: [AgentConfig] = pickerAgents + [refineProse]

    static func agent(id: String) -> AgentConfig {
        agentsByID[id] ?? researchQA
    }

    static func tools(for agent: AgentConfig) -> [AgentToolDefinition] {
        var tools: [AgentToolDefinition] = []
        if agent.toolFlags.useVaultRetrieval {
            tools.append(Self.search)
        }
        if agent.toolFlags.allowCreateNote {
            tools.append(contentsOf: [Self.createNote, Self.createDirectory, Self.editNote, Self.appendToNote, Self.deleteNote])
        }
        if agent.toolFlags.allowReadFiles {
            tools.append(contentsOf: [Self.readFile, Self.listFiles])
        }
        return tools
    }

    private static let agentsByID: [String: AgentConfig] = {
        Dictionary(uniqueKeysWithValues: all.map { ($0.id, $0) })
    }()

    // MARK: - Built-in agents

    static let researchQA = AgentConfig(
        id: "research-qa",
        name: "Research Q&A",
        systemPrompt: """
        You are OpenWrite, a local-first research assistant.
        Answer the user's actual question first — including their profession, goals, or scenario when they state it.
        Use vault excerpts only as optional supporting evidence; never open with a vault summary or a list of what notes contain.
        If excerpts do not mention their topic, explain how local linked notes, search, and the graph help researchers and knowledge workers in general.
        Do not quote marketing or welcome-note boilerplate verbatim.
        Cite sources with bracket IDs exactly as given, e.g. [chunk:UUID], only when you rely on an excerpt.
        If excerpts are insufficient, say so briefly and answer from general knowledge only when appropriate.
        Respond in the same language as the user's question. Be concise, factual, and do not invent note content.
        """,
        chunkLimit: 10,
        toolFlags: .retrievalOnly,
        temperature: 0.35,
        maxReferenceExcerpts: 6,
        snippetMaxChars: 420,
        uiSummary: "Direct answers with citations · 10 chunks · temp 0.35",
        answerInstructions: """
        Answer the user's question in clear prose first (1–3 short paragraphs or tight bullets).
        Use excerpts only as supporting evidence. Cite [chunk:UUID] inline when a claim comes from an excerpt.
        """
    )

    static let noteSummarizer = AgentConfig(
        id: "note-summarizer",
        name: "Note Summarizer",
        systemPrompt: """
        You are a note summarizer for OpenWrite. Synthesize ONLY from the provided vault excerpts.
        Do not add facts, names, dates, or claims that are not supported by an excerpt.
        Match the user's language. Stay neutral and factual.
        """,
        chunkLimit: 16,
        toolFlags: .retrievalWithFullNote,
        temperature: 0.15,
        maxReferenceExcerpts: 8,
        snippetMaxChars: 780,
        uiSummary: "Bullet summaries from notes · 16 wide chunks · temp 0.15",
        answerInstructions: """
        Output format (use these headings exactly):
        ## Summary
        One short paragraph (2–4 sentences) capturing the main theme across excerpts.

        ## Key points
        3–7 bullet lines; each line may end with [chunk:UUID] when grounded in one excerpt.

        Do not ask follow-up questions. Do not produce an outline or Q&A preamble.
        """
    )

    static let outlineHelper = AgentConfig(
        id: "outline-helper",
        name: "Outline Helper",
        systemPrompt: """
        You are an outline builder for OpenWrite. Structure ideas ONLY from the provided vault excerpts.
        Do not invent sections, facts, or claims absent from the excerpts.
        Match the user's language.
        """,
        chunkLimit: 8,
        toolFlags: .retrievalOnly,
        temperature: 0.25,
        maxReferenceExcerpts: 5,
        snippetMaxChars: 320,
        uiSummary: "Hierarchical outlines · 8 chunks · temp 0.25",
        answerInstructions: """
        Output format:
        - Start with a single-line title prefixed with `# ` (derived from the user's ask or the dominant excerpt theme).
        - Use `##` and `###` headings for sections and subsections.
        - Under each heading, use `-` bullets (not numbered lists unless the user asked).
        - Add [chunk:UUID] at the end of a bullet when that bullet is grounded in a specific excerpt.
        - No introductory paragraph before the title. No summary section at the end unless the user asked for one.
        """
    )

    static let refineProse = AgentConfig(
        id: "refine-prose",
        name: "Refine prose",
        systemPrompt: """
        You refine the user's selected writing. Return only the improved prose — no preamble, labels, or commentary.
        Preserve meaning, facts, and voice. Improve clarity, flow, and grammar.
        Do not summarize vault notes or add facts that are not in the selection.
        """,
        chunkLimit: 0,
        toolFlags: AgentToolFlags(
            useVaultRetrieval: false,
            allowCreateNote: false,
            allowReadFiles: false,
            passFullNoteContext: false
        ),
        temperature: 0.2,
        maxReferenceExcerpts: 0,
        snippetMaxChars: nil,
        uiSummary: "Editor selection refine only (no vault search)",
        answerInstructions: ""
    )

    // MARK: - Reor tool definitions (metadata; execution in RAG / future vault actions)

    static let search = AgentToolDefinition(
        name: "search",
        displayName: "Search",
        description: """
        Search the local vault index. Supports chunk limits and optional ISO-8601 date bounds \
        (Reor: "what did I work on last week?").
        """,
        parameters: [
            AgentToolParameter(
                name: "query",
                type: "string",
                description: "The query to search for. Use the full user query for best results."
            ),
            AgentToolParameter(
                name: "limit",
                type: "number",
                description: "The number of results to return",
                defaultValue: "20"
            ),
            AgentToolParameter(
                name: "minDate",
                type: "string",
                description: "Minimum note date (ISO 8601: YYYY-MM-DDTHH:mm:ss.sssZ)",
                optional: true
            ),
            AgentToolParameter(
                name: "maxDate",
                type: "string",
                description: "Maximum note date (ISO 8601: YYYY-MM-DDTHH:mm:ss.sssZ)",
                optional: true
            )
        ],
        autoExecute: true
    )

    static let createNote = AgentToolDefinition(
        name: "createNote",
        displayName: "Create Note",
        description: "Create a new note after explicit user confirmation (v2).",
        parameters: [
            AgentToolParameter(name: "filename", type: "string", description: "Filename without extension"),
            AgentToolParameter(name: "content", type: "string", description: "Note body")
        ],
        autoExecute: false
    )

    static let createDirectory = AgentToolDefinition(
        name: "createDirectory",
        displayName: "Create Directory",
        description: "Create a directory after explicit user confirmation (v2).",
        parameters: [
            AgentToolParameter(name: "directoryName", type: "string", description: "Directory name to create")
        ],
        autoExecute: false
    )

    static let readFile = AgentToolDefinition(
        name: "readFile",
        displayName: "Read File",
        description: "Read a vault file after confirmation (v2).",
        parameters: [
            AgentToolParameter(name: "filePath", type: "string", description: "Path of the file to read")
        ],
        autoExecute: false
    )

    static let deleteNote = AgentToolDefinition(
        name: "deleteNote",
        displayName: "Delete Note",
        description: "Delete a note after confirmation (v2).",
        parameters: [
            AgentToolParameter(name: "filename", type: "string", description: "Filename of the note to delete")
        ],
        autoExecute: false
    )

    static let editNote = AgentToolDefinition(
        name: "editNote",
        displayName: "Edit Note",
        description: "Replace note content after confirmation (v2).",
        parameters: [
            AgentToolParameter(name: "filename", type: "string", description: "Filename of the note to edit"),
            AgentToolParameter(name: "content", type: "string", description: "New note content")
        ],
        autoExecute: false
    )

    static let appendToNote = AgentToolDefinition(
        name: "appendToNote",
        displayName: "Append to Note",
        description: "Append to a note after confirmation (v2).",
        parameters: [
            AgentToolParameter(name: "filename", type: "string", description: "Filename of the note"),
            AgentToolParameter(name: "content", type: "string", description: "Content to append")
        ],
        autoExecute: false
    )

    static let listFiles = AgentToolDefinition(
        name: "listFiles",
        displayName: "List Files",
        description: "List files in the vault (v2).",
        parameters: [],
        autoExecute: true
    )

    static let allToolDefinitions: [AgentToolDefinition] = [
        search,
        createNote,
        createDirectory,
        readFile,
        deleteNote,
        editNote,
        appendToNote,
        listFiles
    ]
}
