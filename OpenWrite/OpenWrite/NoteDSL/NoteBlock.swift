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
        /// Typed page property line — serialized as `@key value` in NDL v0.
        case property
    }

    /// Property field key when `kind == .property` (stored in `text` as fallback).
    var propertyKey: PagePropertyKey? {
        if let key = attributes["key"], let parsed = PagePropertyKey(rawValue: key) {
            return parsed
        }
        return PagePropertyKey(rawValue: text)
    }

    var propertyValuePayload: String {
        if kind == .property {
            return attributes["value"] ?? ""
        }
        return text
    }

    static func propertyBlock(key: PagePropertyKey, value: String) -> NoteBlock {
        NoteBlock(
            kind: .property,
            text: key.rawValue,
            attributes: ["key": key.rawValue, "value": value]
        )
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
        case .property: return "@"
        }
    }
}

enum NDLSerializer {
    /// Minimal v0: one block per line using kind prefixes.
    static func serialize(blocks: [NoteBlock]) -> String {
        blocks.map(serializeBlock).joined(separator: "\n\n")
    }

    static func serializeBlock(_ block: NoteBlock) -> String {
        switch block.kind {
        case .wikilink:
            return "[[\(block.text)]]"
        case .code:
            let lang = block.attributes["language"] ?? ""
            return "```\(lang)\n\(block.text)\n```"
        case .divider:
            return "---"
        case .property:
            let key = block.propertyKey?.rawValue ?? block.text
            let value = block.propertyValuePayload
            return "@\(key) \(escapePropertyValue(value))"
        default:
            return block.kind.ndlLinePrefix + block.text
        }
    }

    private static func escapePropertyValue(_ value: String) -> String {
        value.contains("\n") ? value.replacingOccurrences(of: "\n", with: "\\n") : value
    }

    /// Front-matter style property section followed by body blocks.
    static func serialize(document: VaultDocument) -> String {
        let propertyBlocks = propertyBlocks(from: document.properties, pageType: document.pageType)
        let bodyBlocks = document.rootBlocks.filter { $0.kind != .property }
        return serialize(blocks: propertyBlocks + bodyBlocks)
    }

    static func propertyBlocks(from properties: PageProperties, pageType: PageType) -> [NoteBlock] {
        PageProperties.schema(for: pageType).compactMap { key in
            guard let value = properties[key] else { return nil }
            let payload = value.textRepresentation
            guard !payload.isEmpty else { return nil }
            return NoteBlock.propertyBlock(key: key, value: payload)
        }
    }
}
