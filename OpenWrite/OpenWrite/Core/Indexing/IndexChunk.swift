import Foundation

/// A searchable slice of vault content (heading group or block cluster).
struct IndexChunk: Identifiable, Hashable, Sendable {
    let id: UUID
    let documentID: UUID
    let documentTitle: String
    let blockID: UUID?
    let chunkIndex: Int
    let text: String

    init(
        id: UUID = UUID(),
        documentID: UUID,
        documentTitle: String,
        blockID: UUID?,
        chunkIndex: Int,
        text: String
    ) {
        self.id = id
        self.documentID = documentID
        self.documentTitle = documentTitle
        self.blockID = blockID
        self.chunkIndex = chunkIndex
        self.text = text
    }

    var fusionKey: String {
        "\(documentID.uuidString)-\(blockID?.uuidString ?? "nil")-\(chunkIndex)"
    }
}

enum TextChunker {
    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "this", "that", "from", "your", "have"
    ]

    /// Splits note blocks into retrieval chunks (heading-bounded groups, Reor-style).
    static func chunks(documentID: UUID, title: String, blocks: [NoteBlock]) -> [IndexChunk] {
        var result: [IndexChunk] = []
        var buffer: [String] = []
        var bufferBlockID: UUID?
        var chunkIndex = 0

        func flush() {
            let joined = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !joined.isEmpty else {
                buffer.removeAll()
                return
            }
            result.append(
                IndexChunk(
                    documentID: documentID,
                    documentTitle: title,
                    blockID: bufferBlockID,
                    chunkIndex: chunkIndex,
                    text: joined
                )
            )
            chunkIndex += 1
            buffer.removeAll()
            bufferBlockID = nil
        }

        func visit(_ block: NoteBlock) {
            switch block.kind {
            case .heading1, .heading2, .heading3:
                flush()
                buffer.append(block.text)
                bufferBlockID = block.id
                flush()
            case .divider:
                flush()
            default:
                if !block.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    if bufferBlockID == nil { bufferBlockID = block.id }
                    buffer.append(plainLine(for: block))
                }
            }
            for child in block.children {
                visit(child)
            }
        }

        for block in blocks {
            visit(block)
        }
        flush()

        if result.isEmpty, !title.isEmpty {
            result.append(
                IndexChunk(
                    documentID: documentID,
                    documentTitle: title,
                    blockID: nil,
                    chunkIndex: 0,
                    text: title
                )
            )
        }
        return result
    }

    static func keywordTokens(from query: String) -> [String] {
        query
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 && !stopWords.contains($0) }
    }

    private static func plainLine(for block: NoteBlock) -> String {
        switch block.kind {
        case .wikilink:
            return "[[\(block.text)]]"
        case .bullet:
            return "- \(block.text)"
        case .quote:
            return "> \(block.text)"
        default:
            return block.text
        }
    }
}
