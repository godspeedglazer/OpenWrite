import AppKit
import Foundation

/// Converts HTML / RTF clipboard payloads into NDL blocks (Notion, Craft, web).
enum RichPasteImporter {
    /// Multi-block paste when the pasteboard carries structured rich text.
    static func blocksFromPasteboard(_ pasteboard: NSPasteboard = .general) -> [NoteBlock]? {
        if let html = pasteboard.string(forType: .html), !html.isEmpty,
           let blocks = blocksFromHTML(html), blocks.count > 1 {
            return blocks
        }
        if let rtf = pasteboard.data(forType: .rtf),
           let attributed = try? NSAttributedString(
               data: rtf,
               options: [.documentType: NSAttributedString.DocumentType.rtf],
               documentAttributes: nil
           ),
           let blocks = blocksFromPlainText(attributed.string), blocks.count > 1 {
            return blocks
        }
        return nil
    }

    static func blocksFromHTML(_ html: String) -> [NoteBlock]? {
        guard let data = html.data(using: .utf8) else { return nil }
        guard let attributed = try? NSAttributedString(
            data: data,
            options: [
                .documentType: NSAttributedString.DocumentType.html,
                .characterEncoding: String.Encoding.utf8.rawValue
            ],
            documentAttributes: nil
        ), attributed.length > 0 else { return nil }
        return blocksFromPlainText(attributed.string)
    }

    static func blocksFromPlainText(_ text: String) -> [NoteBlock]? {
        let normalized = text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        let chunks = normalized
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !chunks.isEmpty else { return nil }

        var blocks: [NoteBlock] = []
        for chunk in chunks {
            let lines = chunk.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
            if lines.count == 1 {
                blocks.append(blockForLine(lines[0]))
            } else {
                for line in lines where !line.trimmingCharacters(in: .whitespaces).isEmpty {
                    blocks.append(blockForLine(line))
                }
            }
        }
        return blocks.isEmpty ? nil : blocks
    }

    private static func blockForLine(_ line: String) -> NoteBlock {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return NoteBlock(kind: .paragraph, text: "") }
        if trimmed.hasPrefix("• ") {
            return NoteBlock(kind: .bullet, text: String(trimmed.dropFirst(2)))
        }
        if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            return NoteBlock(kind: .bullet, text: String(trimmed.dropFirst(2)))
        }
        let parsed = NDLParser.parse(trimmed)
        if let first = parsed.first,
           first.kind != .paragraph || first.text != trimmed || trimmed.hasPrefix("#") || trimmed.hasPrefix(">") {
            return first
        }
        return NoteBlock(kind: .paragraph, text: trimmed)
    }
}
