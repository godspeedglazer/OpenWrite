import Foundation

/// Print-style morning layouts filled from local notes (retrieval + recent files).
enum MorningPaperTemplate: String, CaseIterable, Identifiable, Sendable {
    case brief
    case column
    case digest

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .brief: return "Brief"
        case .column: return "Column"
        case .digest: return "Digest card"
        }
    }
}

struct MorningPaperSlots: Sendable {
    var dateLine: String
    var headlines: [String]
    var storyLines: [String]
    var sourceLabels: [String]
}

enum MorningPaperGenerator {
    private static let headlineQueries = [
        "recent updates projects notes",
        "yesterday news daily brief",
        "tasks priorities this week"
    ]

    /// Gathers local-only story material (hybrid search + recent markdown titles).
    static func gatherSlots(
        retrieval: RetrievalService,
        vaultRoot: URL,
        documents: [VaultDocument]
    ) async -> MorningPaperSlots {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        formatter.timeStyle = .none
        let dateLine = formatter.string(from: Date())

        var headlines: [String] = []
        var stories: [String] = []
        var sources: [String] = []
        var seen = Set<String>()

        for query in headlineQueries {
            guard let hits = try? await retrieval.search(query: query, limit: 4) else { continue }
            for hit in hits {
                let key = "\(hit.documentID.uuidString)-\(hit.chunkIndex)"
                guard seen.insert(key).inserted else { continue }
                let title = hit.documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                if !title.isEmpty, headlines.count < 5 {
                    headlines.append(title)
                }
                let snippet = hit.snippet.trimmingCharacters(in: .whitespacesAndNewlines)
                if !snippet.isEmpty, stories.count < 6 {
                    stories.append(snippet)
                }
                if let file = hit.sourceFilename, !file.isEmpty {
                    sources.append(file)
                } else {
                    sources.append(title)
                }
            }
        }

        let recentFiles = VaultMarkdownCatalog.scan(vaultRoot: vaultRoot)
            .sorted { $0.modifiedAt > $1.modifiedAt }
            .prefix(4)
        for file in recentFiles {
            if headlines.count < 6 {
                headlines.append(file.title)
            }
            sources.append(file.sourceFilename)
        }

        if headlines.isEmpty {
            for doc in documents.prefix(4) {
                headlines.append(doc.title)
            }
        }
        if stories.isEmpty {
            stories = [
                "OpenWrite pulled these lines from your indexed notes. Add more `.md` pages under your notes folder, then reindex in Settings → AI."
            ]
        }

        return MorningPaperSlots(
            dateLine: dateLine,
            headlines: Array(headlines.prefix(5)),
            storyLines: Array(stories.prefix(5)),
            sourceLabels: Array(sources.prefix(6))
        )
    }

    static func blocks(template: MorningPaperTemplate, slots: MorningPaperSlots) -> [NoteBlock] {
        switch template {
        case .brief:
            return briefBlocks(slots: slots)
        case .column:
            return columnBlocks(slots: slots)
        case .digest:
            return digestBlocks(slots: slots)
        }
    }

    static func pageTitle(template: MorningPaperTemplate, slots: MorningPaperSlots) -> String {
        "Morning Paper · \(template.displayName) · \(slots.dateLine)"
    }

    private static func briefBlocks(slots: MorningPaperSlots) -> [NoteBlock] {
        var blocks: [NoteBlock] = [
            NoteBlock(kind: .heading1, text: "Morning Brief"),
            NoteBlock(kind: .paragraph, text: slots.dateLine),
            NoteBlock(kind: .heading2, text: "Headlines"),
        ]
        for headline in slots.headlines {
            blocks.append(NoteBlock(kind: .bullet, text: headline))
        }
        blocks.append(NoteBlock(kind: .heading2, text: "From your notes"))
        for line in slots.storyLines.prefix(3) {
            blocks.append(NoteBlock(kind: .paragraph, text: line))
        }
        if !slots.sourceLabels.isEmpty {
            blocks.append(NoteBlock(kind: .callout, text: "Sources: \(slots.sourceLabels.prefix(4).joined(separator: ", "))", attributes: ["callout": "note"]))
        }
        return blocks
    }

    private static func columnBlocks(slots: MorningPaperSlots) -> [NoteBlock] {
        let lede = slots.storyLines.first ?? "Your library is quiet this morning — add notes or open Welcome.md to seed retrieval."
        var blocks: [NoteBlock] = [
            NoteBlock(kind: .heading1, text: slots.headlines.first ?? "Morning column"),
            NoteBlock(kind: .paragraph, text: slots.dateLine),
            NoteBlock(kind: .paragraph, text: lede),
            NoteBlock(kind: .heading2, text: "Also on your desk"),
        ]
        for headline in slots.headlines.dropFirst().prefix(4) {
            blocks.append(NoteBlock(kind: .bullet, text: headline))
        }
        for line in slots.storyLines.dropFirst().prefix(2) {
            blocks.append(NoteBlock(kind: .quote, text: line))
        }
        return blocks
    }

    private static func digestBlocks(slots: MorningPaperSlots) -> [NoteBlock] {
        var blocks: [NoteBlock] = [
            NoteBlock(kind: .callout, text: "Local digest · \(slots.dateLine)", attributes: ["callout": "tip"]),
            NoteBlock(kind: .heading2, text: "Topics"),
        ]
        for headline in slots.headlines {
            blocks.append(NoteBlock(kind: .todo, text: "Read: \(headline)"))
        }
        blocks.append(NoteBlock(kind: .heading2, text: "Excerpts"))
        for line in slots.storyLines.prefix(4) {
            blocks.append(NoteBlock(kind: .paragraph, text: line))
        }
        return blocks
    }
}
