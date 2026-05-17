import Foundation

/// NDL v0 block — canonical in-memory unit for note content.
struct NoteBlock: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var kind: Kind
    var text: String
    var children: [NoteBlock]
    var attributes: [String: String]

    init(
        id: UUID = UUID(),
        kind: Kind,
        text: String,
        children: [NoteBlock] = [],
        attributes: [String: String] = [:]
    ) {
        self.id = id
        self.kind = kind
        self.text = text
        self.children = children
        self.attributes = attributes
    }

    enum Kind: String, Codable, CaseIterable, Sendable {
        case paragraph
        case heading1
        case heading2
        case heading3
        case bullet
        case quote
        case code
        case divider
        case wikilink
    }
}

// MARK: - NDL v0 line hints (serializer/parser stubs)

extension NoteBlock.Kind {
    /// Line prefix for NDL v0 serialization (Phase 1 stub).
    var ndlLinePrefix: String {
        switch self {
        case .paragraph: return ""
        case .heading1: return "# "
        case .heading2: return "## "
        case .heading3: return "### "
        case .bullet: return "- "
        case .quote: return "> "
        case .code: return "```"
        case .divider: return "---"
        case .wikilink: return "[["
        }
    }
}

enum NDLSerializer {
    /// Minimal v0: one block per line using kind prefixes.
    static func serialize(blocks: [NoteBlock]) -> String {
        blocks.map { block in
            switch block.kind {
            case .wikilink:
                return "[[\(block.text)]]"
            case .code:
                let lang = block.attributes["language"] ?? ""
                return "```\(lang)\n\(block.text)\n```"
            case .divider:
                return "---"
            default:
                return block.kind.ndlLinePrefix + block.text
            }
        }
        .joined(separator: "\n\n")
    }
}
