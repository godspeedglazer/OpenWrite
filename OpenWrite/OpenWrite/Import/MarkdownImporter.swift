import Foundation

/// Imports Markdown files into NDL block trees (major ride stub).
struct MarkdownImporter: Sendable {
    func importFile(at url: URL) throws -> [NoteBlock] {
        let markdown = try String(contentsOf: url, encoding: .utf8)
        return importString(markdown)
    }

    func importString(_ markdown: String) -> [NoteBlock] {
        NDLParser.parse(markdown)
    }
}
