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
    /// Reor `keywordSearch` stop list (`db.ts`).
    private static let stopWords: Set<String> = [
        "the", "and", "for", "with", "this", "that"
    ]

    /// Splits note blocks into retrieval chunks (heading-bounded, then recursive if oversized).
    static func chunks(documentID: UUID, title: String, blocks: [NoteBlock]) -> [IndexChunk] {
        var headingChunks: [(blockID: UUID?, text: String)] = []
        var buffer: [String] = []
        var bufferBlockID: UUID?

        func flush() {
            let joined = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            guard !joined.isEmpty else {
                buffer.removeAll()
                return
            }
            headingChunks.append((bufferBlockID, joined))
            buffer.removeAll()
            bufferBlockID = nil
        }

        func visit(_ block: NoteBlock) {
            switch block.kind {
            case .heading1, .heading2, .heading3:
                flush()
                buffer.append(plainLine(for: block))
                if bufferBlockID == nil { bufferBlockID = block.id }
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

        if headingChunks.isEmpty, !title.isEmpty {
            headingChunks.append((nil, title))
        }

        let maxChars = AISafetyLimits.indexChunkMaxChars
        let overlap = AISafetyLimits.indexChunkOverlap
        var result: [IndexChunk] = []
        var chunkIndex = 0

        for group in headingChunks {
            let pieces = group.text.count > maxChars
                ? splitRecursively(group.text, maxChars: maxChars, overlap: overlap)
                : [group.text]
            for piece in pieces {
                let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                result.append(
                    IndexChunk(
                        documentID: documentID,
                        documentTitle: title,
                        blockID: group.blockID,
                        chunkIndex: chunkIndex,
                        text: trimmed
                    )
                )
                chunkIndex += 1
            }
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

    private static func plainLine(for block: NoteBlock) -> String {
        switch block.kind {
        case .wikilink:
            return "[[\(block.text)]]"
        case .bullet:
            return "- \(block.text)"
        case .quote:
            return "> \(block.text)"
        case .callout:
            let type = block.attributes["callout"] ?? "note"
            return "> [!\(type)] \(block.text)"
        default:
            return block.text
        }
    }
}
