import Foundation

enum NDLParser {
    /// Parses NDL v0 source into blocks; recognizes `@key value` property lines.
    static func parse(_ source: String) -> [NoteBlock] {
        let lines = source
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return [NoteBlock(kind: .paragraph, text: "")]
        }

        return lines.compactMap { line in
            if let block = parsePrefixedLine(line) {
                return block
            }
            return NoteBlock(kind: .paragraph, text: line)
        }
    }

    /// Split property blocks from body content and hydrate a property bag.
    static func parseDocument(
        source: String,
        pageType: PageType,
        title: String
    ) -> (properties: PageProperties, bodyBlocks: [NoteBlock]) {
        let blocks = parse(source)
        var properties = PageProperties.defaults(for: pageType, title: title)
        var body: [NoteBlock] = []

        for block in blocks {
            if block.kind == .property, let key = block.propertyKey {
                let payload = block.propertyValuePayload
                if let value = PagePropertyValue(ndlPayload: payload, for: key) {
                    properties[key] = value
                }
            } else {
                body.append(block)
            }
        }
        return (properties, body)
    }

    private static func parsePrefixedLine(_ line: String) -> NoteBlock? {
        if line == "---" {
            return NoteBlock(kind: .divider, text: "")
        }
        if line.hasPrefix("@") {
            return parsePropertyLine(line)
        }
        if line.hasPrefix("### ") {
            return NoteBlock(kind: .heading3, text: String(line.dropFirst(4)))
        }
        if line.hasPrefix("## ") {
            return NoteBlock(kind: .heading2, text: String(line.dropFirst(3)))
        }
        if line.hasPrefix("# ") {
            return NoteBlock(kind: .heading1, text: String(line.dropFirst(2)))
        }
        if line.hasPrefix("- ") {
            return NoteBlock(kind: .bullet, text: String(line.dropFirst(2)))
        }
        if let callout = parseCalloutLine(line) {
            return callout
        }
        if line.hasPrefix("> ") {
            return NoteBlock(kind: .quote, text: String(line.dropFirst(2)))
        }
        if line.hasPrefix("[["), line.hasSuffix("]]") {
            let inner = line.dropFirst(2).dropLast(2)
            return NoteBlock(kind: .wikilink, text: String(inner))
        }
        return nil
    }

    private static func parseCalloutLine(_ line: String) -> NoteBlock? {
        guard line.hasPrefix("> [!"), let close = line.firstIndex(of: "]") else { return nil }
        let typeStart = line.index(line.startIndex, offsetBy: 4)
        guard typeStart < close else { return nil }
        let calloutType = String(line[typeStart..<close]).trimmingCharacters(in: .whitespaces)
        guard !calloutType.isEmpty else { return nil }
        var body = ""
        let afterClose = line.index(after: close)
        if afterClose < line.endIndex {
            body = String(line[afterClose...]).trimmingCharacters(in: .whitespaces)
        }
        return NoteBlock(kind: .callout, text: body, attributes: ["callout": calloutType])
    }

    private static func parsePropertyLine(_ line: String) -> NoteBlock? {
        let body = String(line.dropFirst())
        guard let space = body.firstIndex(where: { $0 == " " || $0 == "\t" }) else {
            let key = body.trimmingCharacters(in: .whitespaces)
            guard PagePropertyKey(rawValue: key) != nil else { return nil }
            return NoteBlock.propertyBlock(key: PagePropertyKey(rawValue: key)!, value: "")
        }
        let keyRaw = String(body[..<space])
        guard let key = PagePropertyKey(rawValue: keyRaw) else { return nil }
        var value = String(body[body.index(after: space)...])
        value = value.replacingOccurrences(of: "\\n", with: "\n")
        return NoteBlock.propertyBlock(key: key, value: value)
    }
}
