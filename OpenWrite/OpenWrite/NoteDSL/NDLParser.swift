import Foundation

enum NDLParser {
    /// Phase 1 stub: treats each non-empty line as a paragraph block.
    static func parse(_ source: String) -> [NoteBlock] {
        let lines = source
            .split(whereSeparator: \.isNewline)
            .map { String($0).trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        guard !lines.isEmpty else {
            return [NoteBlock(kind: .paragraph, text: "")]
        }

        return lines.map { line in
            if let block = parsePrefixedLine(line) {
                return block
            }
            return NoteBlock(kind: .paragraph, text: line)
        }
    }

    private static func parsePrefixedLine(_ line: String) -> NoteBlock? {
        if line == "---" {
            return NoteBlock(kind: .divider, text: "")
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
        if line.hasPrefix("> ") {
            return NoteBlock(kind: .quote, text: String(line.dropFirst(2)))
        }
        if line.hasPrefix("[["), line.hasSuffix("]]") {
            let inner = line.dropFirst(2).dropLast(2)
            return NoteBlock(kind: .wikilink, text: String(inner))
        }
        return nil
    }
}
