import Foundation

struct ResearchDigestSource: Identifiable, Hashable, Sendable {
    let id: UUID
    let title: String
    let excerpt: String
    let sourceLabel: String
}

enum ResearchDigestBuilder {
    /// Builds a summarizer query from selected vault pages (in-memory + on-disk titles).
    static func query(sources: [ResearchDigestSource]) -> String {
        let list = sources.map { source in
            """
            ### \(source.title) (\(source.sourceLabel))
            \(source.excerpt)
            """
        }.joined(separator: "\n\n")
        return """
        Produce a research digest across these notes. Tie themes together; flag contradictions gently.

        \(list)
        """
    }

    static func sources(
        from documents: [VaultDocument],
        markdownFiles: [VaultMarkdownFile],
        selectedDocumentIDs: Set<UUID>,
        selectedRelativePaths: Set<String>
    ) -> [ResearchDigestSource] {
        var results: [ResearchDigestSource] = []

        for doc in documents where selectedDocumentIDs.contains(doc.id) {
            let excerpt = doc.rootBlocks
                .filter { $0.kind != .property && $0.kind != .divider && $0.kind != .image }
                .map(\.text)
                .joined(separator: "\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !excerpt.isEmpty else { continue }
            results.append(
                ResearchDigestSource(
                    id: doc.id,
                    title: doc.title,
                    excerpt: String(excerpt.prefix(2400)),
                    sourceLabel: "in-app page"
                )
            )
        }

        for file in markdownFiles where selectedRelativePaths.contains(file.relativePath) {
            guard let blocks = try? VaultMarkdownCatalog.loadBlocks(from: file) else { continue }
            let excerpt = blocks.map(\.text).joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !excerpt.isEmpty else { continue }
            results.append(
                ResearchDigestSource(
                    id: file.documentID,
                    title: file.title,
                    excerpt: String(excerpt.prefix(2400)),
                    sourceLabel: file.sourceFilename
                )
            )
        }

        return results
    }

    static func digestBlocks(title: String, body: String) -> [NoteBlock] {
        let trimmed = body.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            return [
                NoteBlock(kind: .heading1, text: title),
                NoteBlock(kind: .paragraph, text: "No digest text was returned.")
            ]
        }
        var blocks: [NoteBlock] = [NoteBlock(kind: .heading1, text: title)]
        let sections = trimmed.components(separatedBy: "\n\n")
        for section in sections {
            let line = section.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !line.isEmpty else { continue }
            if line.hasPrefix("## ") {
                blocks.append(NoteBlock(kind: .heading2, text: String(line.dropFirst(3))))
            } else if line.hasPrefix("- ") {
                blocks.append(NoteBlock(kind: .bullet, text: String(line.dropFirst(2))))
            } else {
                blocks.append(NoteBlock(kind: .paragraph, text: line))
            }
        }
        return blocks
    }
}
