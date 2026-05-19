// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Chunking adapted from Reor (https://github.com/reorproject/reor)
// `electron/main/common/chunking.ts` — heading splits + recursive character chunks.
// Swift reimplementation only; see OpenWrite/AI/ReorPortNotes.md for AGPL scope.

import Foundation

/// A searchable slice of vault content (heading group or block cluster).
struct IndexChunk: Identifiable, Hashable, Sendable {
    let id: UUID
    let documentID: UUID
    let documentTitle: String
    /// Reor-style citation label, e.g. `Welcome.md` for on-disk markdown vault files.
    let sourceFilename: String?
    let blockID: UUID?
    let chunkIndex: Int
    /// Full retrieval payload (header + section + body) embedded and keyword-scanned.
    let text: String
    /// Breadcrumb for the heading group, e.g. `Overnight > Markets`.
    let headingPath: String?
    let documentUpdatedAt: Date?
    /// High-recall chunk repeating title + filename for “find this note” queries.
    let isTitleLeadChunk: Bool

    init(
        id: UUID = UUID(),
        documentID: UUID,
        documentTitle: String,
        sourceFilename: String? = nil,
        blockID: UUID?,
        chunkIndex: Int,
        text: String,
        headingPath: String? = nil,
        documentUpdatedAt: Date? = nil,
        isTitleLeadChunk: Bool = false
    ) {
        self.id = id
        self.documentID = documentID
        self.documentTitle = documentTitle
        self.sourceFilename = sourceFilename
        self.blockID = blockID
        self.chunkIndex = chunkIndex
        self.text = text
        self.headingPath = headingPath
        self.documentUpdatedAt = documentUpdatedAt
        self.isTitleLeadChunk = isTitleLeadChunk
    }

    var fusionKey: String {
        "\(documentID.uuidString)-\(blockID?.uuidString ?? "nil")-\(chunkIndex)"
    }

    /// Body text for LLM snippets (drops repeated page header).
    var snippetText: String {
        TextChunker.stripRetrievalHeader(from: text)
    }
}

enum TextChunker {
    /// Reor `keywordSearch` stop list (`db.ts`).
    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "this", "that"
    ]

    /// Splits note blocks into retrieval chunks (heading-bounded, then recursive if oversized).
    static func chunks(
        documentID: UUID,
        title: String,
        blocks: [NoteBlock],
        sourceFilename: String? = nil,
        documentUpdatedAt: Date? = nil
    ) -> [IndexChunk] {
        var headingChunks: [(blockID: UUID?, headingPath: String?, text: String)] = []
        var buffer: [String] = []
        var bufferBlockID: UUID?
        var headingLevels: [String?] = [nil, nil, nil]

        func headingPathString() -> String? {
            let parts = headingLevels.compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            return parts.isEmpty ? nil : parts.joined(separator: " > ")
        }

        func flush() {
            let joined = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !joined.isEmpty else {
                buffer.removeAll()
                return
            }
            headingChunks.append((bufferBlockID, headingPathString(), joined))
            buffer.removeAll()
            bufferBlockID = nil
        }

        func setHeading(level: Int, text: String) {
            let index = min(max(level - 1, 0), 2)
            headingLevels[index] = text
            for i in (index + 1) ..< headingLevels.count {
                headingLevels[i] = nil
            }
        }

        func visit(_ block: NoteBlock) {
            switch block.kind {
            case .heading1:
                flush()
                setHeading(level: 1, text: block.text)
                buffer.append(plainLine(for: block))
                if bufferBlockID == nil { bufferBlockID = block.id }
            case .heading2:
                flush()
                setHeading(level: 2, text: block.text)
                buffer.append(plainLine(for: block))
                if bufferBlockID == nil { bufferBlockID = block.id }
            case .heading3:
                flush()
                setHeading(level: 3, text: block.text)
                buffer.append(plainLine(for: block))
                if bufferBlockID == nil { bufferBlockID = block.id }
            case .divider:
                flush()
            case .code:
                break
            default:
                let line = plainLine(for: block)
                guard !line.isEmpty else { break }
                if bufferBlockID == nil { bufferBlockID = block.id }
                buffer.append(line)
            }
            for child in block.children {
                visit(child)
            }
        }

        for block in blocks {
            visit(block)
        }
        flush()

        if headingChunks.isEmpty, !title.isEmpty {
            headingChunks.append((nil, nil, title))
        }

        let maxChars = AISafetyLimits.indexChunkMaxChars
        let overlap = AISafetyLimits.indexChunkOverlap
        var result: [IndexChunk] = []
        var chunkIndex = 0

        if let lead = titleLeadChunk(
            documentID: documentID,
            title: title,
            blocks: blocks,
            sourceFilename: sourceFilename,
            documentUpdatedAt: documentUpdatedAt,
            chunkIndex: chunkIndex
        ) {
            result.append(lead)
            chunkIndex += 1
        }

        var priorSectionTail = ""

        for group in headingChunks {
            var body = group.text
            if !priorSectionTail.isEmpty {
                let bridged = priorSectionTail + body
                if bridged.count <= maxChars {
                    body = bridged
                }
            }

            let pieces = body.count > maxChars
                ? splitRecursively(body, maxChars: maxChars, overlap: overlap)
                : [body]

            for piece in pieces {
                let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                let sectionBody = sectionBodyText(headingPath: group.headingPath, body: trimmed)
                result.append(
                    IndexChunk(
                        documentID: documentID,
                        documentTitle: title,
                        sourceFilename: sourceFilename,
                        blockID: group.blockID,
                        chunkIndex: chunkIndex,
                        text: embedRetrievalHeader(
                            title: title,
                            updatedAt: documentUpdatedAt,
                            body: sectionBody
                        ),
                        headingPath: group.headingPath,
                        documentUpdatedAt: documentUpdatedAt,
                        isTitleLeadChunk: false
                    )
                )
                chunkIndex += 1
            }

            if let last = pieces.last {
                priorSectionTail = String(last.suffix(min(overlap, last.count)))
            } else {
                priorSectionTail = ""
            }
        }
        return result
    }

    static func stripRetrievalHeader(from text: String) -> String {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        guard !lines.isEmpty else { return text }
        var index = 0
        if lines[0].hasPrefix("Page:") {
            index = 1
            while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
            }
        }
        if index < lines.count, lines[index].hasPrefix("Section:") {
            index += 1
            while index < lines.count, lines[index].trimmingCharacters(in: .whitespaces).isEmpty {
                index += 1
            }
        }
        guard index < lines.count else { return text }
        return lines[index...].joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func keywordTokens(from query: String) -> [String] {
        query
            .lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .map(String.init)
            .filter { $0.count > 2 && !stopWords.contains($0) }
    }

    /// Reor `chunkStringsRecursively` / LangChain `RecursiveCharacterTextSplitter` separator order.
    static func splitRecursively(
        _ text: String,
        maxChars: Int,
        overlap: Int,
        separators: [String] = ["\n\n", "\n", " ", ""]
    ) -> [String] {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return [] }
        guard trimmed.count > maxChars else { return [trimmed] }

        let separator = separators.first ?? ""
        let nextSeparators = separators.count > 1 ? Array(separators.dropFirst()) : [""]
        let parts = splitKeepingSeparator(trimmed, separator: separator)

        if parts.count == 1, !nextSeparators.isEmpty {
            return splitRecursively(trimmed, maxChars: maxChars, overlap: overlap, separators: nextSeparators)
        }

        var merged: [String] = []
        var current = ""

        func flushCurrent() {
            let piece = current.trimmingCharacters(in: .whitespacesAndNewlines)
            if !piece.isEmpty { merged.append(piece) }
            current = ""
        }

        for part in parts {
            let candidate = current.isEmpty ? part : current + part
            if candidate.count <= maxChars {
                current = candidate
            } else if current.isEmpty {
                if part.count > maxChars, !nextSeparators.isEmpty {
                    merged.append(contentsOf: splitRecursively(part, maxChars: maxChars, overlap: overlap, separators: nextSeparators))
                } else {
                    merged.append(part)
                }
            } else {
                flushCurrent()
                if part.count > maxChars, !nextSeparators.isEmpty {
                    merged.append(contentsOf: splitRecursively(part, maxChars: maxChars, overlap: overlap, separators: nextSeparators))
                } else {
                    current = part
                }
            }
        }
        flushCurrent()

        return applyOverlap(to: merged, maxChars: maxChars, overlap: overlap)
    }

    private static func sectionBodyText(headingPath: String?, body: String) -> String {
        guard let headingPath, !headingPath.isEmpty else { return body }
        return "Section: \(headingPath)\n\n\(body)"
    }

    private static func titleLeadChunk(
        documentID: UUID,
        title: String,
        blocks: [NoteBlock],
        sourceFilename: String?,
        documentUpdatedAt: Date?,
        chunkIndex: Int
    ) -> IndexChunk? {
        guard !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
        var lines: [String] = [title]
        if let sourceFilename, !sourceFilename.isEmpty {
            lines.append("File: \(sourceFilename)")
        }
        let preview = firstParagraphPreview(from: blocks)
        if !preview.isEmpty {
            lines.append(preview)
        }
        let wikilinks = collectWikilinks(from: blocks, limit: 8)
        if !wikilinks.isEmpty {
            lines.append("Links: " + wikilinks.joined(separator: ", "))
        }
        let body = lines.joined(separator: "\n")
        return IndexChunk(
            documentID: documentID,
            documentTitle: title,
            sourceFilename: sourceFilename,
            blockID: nil,
            chunkIndex: chunkIndex,
            text: embedRetrievalHeader(title: title, updatedAt: documentUpdatedAt, body: body),
            headingPath: nil,
            documentUpdatedAt: documentUpdatedAt,
            isTitleLeadChunk: true
        )
    }

    private static func firstParagraphPreview(from blocks: [NoteBlock], maxChars: Int = 280) -> String {
        for block in blocks {
            if let text = paragraphPreview(from: block) {
                if text.count <= maxChars { return text }
                return String(text.prefix(maxChars))
            }
        }
        return ""
    }

    private static func paragraphPreview(from block: NoteBlock) -> String? {
        switch block.kind {
        case .paragraph, .bullet, .quote, .callout:
            let trimmed = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
            return trimmed.isEmpty ? nil : trimmed
        default:
            break
        }
        for child in block.children {
            if let nested = paragraphPreview(from: child) { return nested }
        }
        return nil
    }

    private static func collectWikilinks(from blocks: [NoteBlock], limit: Int) -> [String] {
        var links: [String] = []
        func visit(_ block: NoteBlock) {
            if block.kind == .wikilink {
                let name = block.text.trimmingCharacters(in: .whitespacesAndNewlines)
                if !name.isEmpty, !links.contains(name) { links.append(name) }
            }
            for child in block.children { visit(child) }
        }
        for block in blocks {
            visit(block)
            if links.count >= limit { break }
        }
        return Array(links.prefix(limit))
    }

    private static func splitKeepingSeparator(_ text: String, separator: String) -> [String] {
        guard !separator.isEmpty else {
            return text.map { String($0) }
        }
        var parts: [String] = []
        var start = text.startIndex
        var searchStart = text.startIndex
        while searchStart < text.endIndex,
              let range = text.range(of: separator, range: searchStart..<text.endIndex) {
            parts.append(String(text[start..<range.upperBound]))
            start = range.upperBound
            searchStart = range.upperBound
        }
        if start < text.endIndex {
            parts.append(String(text[start..<text.endIndex]))
        }
        return parts.isEmpty ? [text] : parts
    }

    private static func applyOverlap(to chunks: [String], maxChars: Int, overlap: Int) -> [String] {
        guard overlap > 0, chunks.count > 1 else { return chunks }
        var result: [String] = []
        for (index, chunk) in chunks.enumerated() {
            if index == 0 {
                result.append(chunk)
                continue
            }
            let previous = chunks[index - 1]
            let tail = String(previous.suffix(min(overlap, previous.count)))
            let combined = tail + chunk
            if combined.count <= maxChars {
                result.append(combined)
            } else {
                result.append(chunk)
            }
        }
        return result
    }

    /// Prefix each embedded chunk so lexical + vector search can match dates and titles.
    private static func embedRetrievalHeader(title: String, updatedAt: Date?, body: String) -> String {
        var header = "Page: \(title)"
        if let updatedAt {
            header += " · Updated \(indexDateFormatter.string(from: updatedAt))"
        }
        return "\(header)\n\n\(body)"
    }

    private static let indexDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private static func plainLine(for block: NoteBlock) -> String {
        switch block.kind {
        case .wikilink:
            return "[[\(block.text)]]"
        case .bullet:
            return "- \(block.text)"
        case .todo:
            let mark = block.isChecked ? "x" : " "
            return "- [\(mark)] \(block.text)"
        case .quote:
            return "> \(block.text)"
        case .callout:
            let type = block.attributes["callout"] ?? "note"
            return "> [!\(type)] \(block.text)"
        case .code:
            return ""
        case .image:
            return NDLSerializer.serializeBlock(block)
        default:
            return block.text
        }
    }
}
