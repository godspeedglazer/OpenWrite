import Foundation

enum NDLParser {
    /// Parses NDL v0 source into blocks; recognizes `@key value` property lines and fenced code.
    static func parse(_ source: String) -> [NoteBlock] {
        let rawLines = source.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map(String.init)
        guard !rawLines.isEmpty else {
            return [NoteBlock(kind: .paragraph, text: "")]
        }

        var blocks: [NoteBlock] = []
        var index = 0
        while index < rawLines.count {
            let trimmed = rawLines[index].trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("```") {
                let language = String(trimmed.dropFirst(3)).trimmingCharacters(in: .whitespaces)
                index += 1
                var bodyLines: [String] = []
                while index < rawLines.count {
                    if rawLines[index].trimmingCharacters(in: .whitespaces) == "```" {
                        index += 1
                        break
                    }
                    bodyLines.append(rawLines[index])
                    index += 1
                }
                var attributes: [String: String] = [:]
                if !language.isEmpty {
                    attributes["language"] = language
                }
                blocks.append(NoteBlock(kind: .code, text: bodyLines.joined(separator: "\n"), attributes: attributes))
                continue
            }
            if trimmed.isEmpty {
                index += 1
                continue
            }
            if let block = parsePrefixedLine(trimmed) {
                blocks.append(block)
            } else {
                blocks.append(NoteBlock(kind: .paragraph, text: trimmed))
            }
            index += 1
        }

        return blocks.isEmpty ? [NoteBlock(kind: .paragraph, text: "")] : blocks
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
        if let todo = parseTodoLine(line) {
            return todo
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
        if let image = parseImageLine(line) {
            return image
        }
        return nil
    }

    private static func parseImageLine(_ line: String) -> NoteBlock? {
        guard line.hasPrefix("!["),
              let bracketEnd = line.firstIndex(of: "]"),
              bracketEnd < line.endIndex else { return nil }
        let afterBracket = line.index(after: bracketEnd)
        guard afterBracket < line.endIndex, line[afterBracket] == "(",
              line.hasSuffix(")") else { return nil }

        let altStart = line.index(line.startIndex, offsetBy: 2)
        let alt = String(line[altStart..<bracketEnd])
            .replacingOccurrences(of: "\\]", with: "]")
        let openParen = line.index(after: afterBracket)
        let closeParen = line.index(before: line.endIndex)
        guard openParen <= closeParen else { return nil }
        let target = String(line[openParen...closeParen])

        if target.hasPrefix("asset:") {
            let assetId = String(target.dropFirst("asset:".count))
            guard !assetId.isEmpty else { return nil }
            return NoteBlock(kind: .image, text: alt, attributes: [NoteBlock.assetIdAttributeKey: assetId])
        }
        if target.hasPrefix("path:") {
            let path = String(target.dropFirst("path:".count))
            return NoteBlock(kind: .image, text: alt, attributes: [NoteBlock.pathAttributeKey: path])
        }
        if !target.isEmpty {
            return NoteBlock(kind: .image, text: alt, attributes: [NoteBlock.pathAttributeKey: target])
        }
        return nil
    }

    private static func parseTodoLine(_ line: String) -> NoteBlock? {
        guard line.hasPrefix("- ["), let close = line.firstIndex(of: "]") else { return nil }
        let stateStart = line.index(line.startIndex, offsetBy: 3)
        guard stateStart < close else { return nil }
        let state = line[stateStart..<close]
        guard state.count == 1 else { return nil }
        let checked = state == "x" || state == "X"
        let afterClose = line.index(after: close)
        let text: String
        if afterClose < line.endIndex {
            text = String(line[afterClose...]).trimmingCharacters(in: .whitespaces)
        } else {
            text = ""
        }
        return NoteBlock.todoBlock(text: text, checked: checked)
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
