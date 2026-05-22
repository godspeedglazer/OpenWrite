import Foundation

/// Refine preset instructions shared by inline assist and regression tests.
enum RefinePromptPreset: String, CaseIterable, Sendable {
    case improve
    case shorten
    case fixGrammar

    var instructionSuffix: String {
        switch self {
        case .improve:
            return "Improve clarity, flow, and word choice while preserving meaning and voice."
        case .shorten:
            return "Make the selection more concise. Remove redundancy; keep essential meaning."
        case .fixGrammar:
            return "Fix grammar, punctuation, and spelling only. Do not change meaning or tone."
        }
    }
}

enum RefinePrompts {
    static func buildQuery(
        selection: String,
        preset: RefinePromptPreset,
        noteExcerpt: String?
    ) -> String {
        var body = """
        Refine the following selected excerpt from my note. Return only the improved text. \
        Do not wrap in markdown fences unless the selection already uses them.
        Task: \(preset.instructionSuffix)

        --- SELECTION ---
        \(selection)
        --- END SELECTION ---

        \(OWActionScript.systemPromptAppendix())
        """
        if let excerpt = noteExcerpt?.trimmingCharacters(in: .whitespacesAndNewlines), !excerpt.isEmpty {
            body += """


            --- NOTE CONTEXT (for tone only; do not quote or summarize) ---
            \(excerpt)
            --- END NOTE CONTEXT ---
            """
        }
        return body
    }
}
