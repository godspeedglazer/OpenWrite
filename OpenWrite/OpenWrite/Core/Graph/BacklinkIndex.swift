import Foundation

/// Wikilink and reference graph index (local-only, in-memory).
struct BacklinkIndex: Sendable {
    private var incoming: [UUID: Set<UUID>] = [:]
    private(set) var outgoing: [UUID: Set<UUID>] = [:]

    mutating func registerLink(from sourceDocumentID: UUID, to targetDocumentID: UUID) {
        guard sourceDocumentID != targetDocumentID else { return }
        incoming[targetDocumentID, default: []].insert(sourceDocumentID)
        outgoing[sourceDocumentID, default: []].insert(targetDocumentID)
    }

    func backlinks(to documentID: UUID) -> [UUID] {
        Array(incoming[documentID] ?? []).sorted { $0.uuidString < $1.uuidString }
    }

    func outlinks(from documentID: UUID) -> [UUID] {
        Array(outgoing[documentID] ?? []).sorted { $0.uuidString < $1.uuidString }
    }

    /// Rebuild adjacency from vault documents and resolved `[[wikilink]]` targets.
    static func build(from documents: [VaultDocument]) -> BacklinkIndex {
        var index = BacklinkIndex()
        let titleMap = titleLookup(for: documents)

        for document in documents {
            for targetTitle in Self.wikilinkTitles(in: document) {
                guard let targetID = titleMap[normalizeTitle(targetTitle)] else { continue }
                index.registerLink(from: document.id, to: targetID)
            }
        }
        return index
    }

    static func wikilinkTitles(in document: VaultDocument) -> [String] {
        wikilinkTitles(in: document.rootBlocks)
    }

    private static func wikilinkTitles(in blocks: [NoteBlock]) -> [String] {
        blocks.flatMap { block -> [String] in
            var titles: [String] = []
            if block.kind == .wikilink {
                let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty { titles.append(trimmed) }
            }
            titles.append(contentsOf: wikilinkTitles(in: block.children))
            return titles
        }
    }

    private static func titleLookup(for documents: [VaultDocument]) -> [String: UUID] {
        var map: [String: UUID] = [:]
        for document in documents {
            let key = normalizeTitle(document.displayTitle)
            if map[key] == nil {
                map[key] = document.id
            }
        }
        return map
    }

    private static func normalizeTitle(_ title: String) -> String {
        title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}
