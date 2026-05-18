import Foundation

/// One vault file or note surfaced in RAG source pills (deduped, chunk count aggregated).
struct RAGDocumentSource: Identifiable, Hashable, Sendable {
    let id: UUID
    let documentID: UUID
    let primaryLabel: String
    let subtitle: String?
    let chunkCount: Int
    /// Sorted 1-based chunk ordinals when multiple slices from the same file were retrieved.
    let chunkOrdinals: [Int]
    let representativeHit: RetrievalHit

    init(
        documentID: UUID,
        primaryLabel: String,
        subtitle: String?,
        chunkCount: Int,
        chunkOrdinals: [Int] = [],
        representativeHit: RetrievalHit
    ) {
        self.id = documentID
        self.documentID = documentID
        self.primaryLabel = primaryLabel
        self.subtitle = subtitle
        self.chunkCount = chunkCount
        self.chunkOrdinals = chunkOrdinals
        self.representativeHit = representativeHit
    }

    var chunkBadge: String? {
        guard chunkCount > 1 else { return nil }
        if chunkOrdinals.count > 1 {
            let listed = chunkOrdinals.prefix(3).map { String($0) }.joined(separator: ", ")
            let suffix = chunkOrdinals.count > 3 ? ", …" : ""
            return "§\(listed)\(suffix)"
        }
        return "×\(chunkCount)"
    }
}

extension Array where Element == RetrievalHit {
    /// One entry per vault document or markdown file, highest-scoring chunk first (Reor source pills).
    func uniqueDocumentSources(limit: Int = 8) -> [RetrievalHit] {
        groupedDocumentSources(limit: limit).map(\.representativeHit)
    }

    /// Deduped sources with filename-first labels and per-document chunk counts.
    func groupedDocumentSources(limit: Int = 8) -> [RAGDocumentSource] {
        var seenKeys = Set<String>()
        var groups: [RAGDocumentSource] = []
        groups.reserveCapacity(Swift.min(limit, count))

        var chunkOrdinalsByKey: [String: Set<Int>] = [:]
        for hit in self where hit.isValidSourcePill {
            let key = hit.sourceDedupeKeys.first ?? "doc:\(hit.documentID.uuidString.lowercased())"
            chunkOrdinalsByKey[key, default: []].insert(hit.chunkIndex + 1)
        }

        for hit in self {
            guard hit.isValidSourcePill else { continue }
            let keys = hit.sourceDedupeKeys
            if keys.contains(where: { seenKeys.contains($0) }) { continue }
            keys.forEach { seenKeys.insert($0) }
            let groupKey = keys.first ?? "doc:\(hit.documentID.uuidString.lowercased())"
            let ordinals: [Int]
            if let ordinalSet = chunkOrdinalsByKey[groupKey] {
                ordinals = ordinalSet.sorted()
            } else {
                ordinals = [hit.chunkIndex + 1]
            }
            let count = ordinals.count
            groups.append(
                RAGDocumentSource(
                    documentID: hit.documentID,
                    primaryLabel: hit.sourcePillPrimary,
                    subtitle: hit.sourcePillSubtitle,
                    chunkCount: count,
                    chunkOrdinals: ordinals,
                    representativeHit: hit
                )
            )
            if groups.count >= limit { break }
        }
        return groups
    }
}

extension RetrievalHit {
    /// Keys for deduping the same note indexed as an in-app page and as on-disk markdown.
    var sourceDedupeKeys: [String] {
        var keys: [String] = []
        if let name = sourceFilename?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            let normalized = name.replacingOccurrences(of: "\\", with: "/").lowercased()
            keys.append("file:\(normalized)")
            let leaf = SourceDisplayName.filename(from: name).lowercased()
            keys.append("leaf:\(leaf)")
            let stem = (leaf as NSString).deletingPathExtension
            if !stem.isEmpty { keys.append("stem:\(stem)") }
        }
        keys.append("doc:\(documentID.uuidString.lowercased())")
        return keys
    }

    /// Primary pill label — vault filename when known (e.g. `Welcome.md`), else note title.
    var sourcePillPrimary: String {
        if let name = sourceFilename?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            return SourceDisplayName.filename(from: name)
        }
        let title = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            if SourceDisplayName.looksLikeFilesystemPath(title) {
                return SourceDisplayName.filename(from: title)
            }
            return title
        }
        return "Untitled"
    }

    /// Secondary line — vault-relative path when indexed from disk; in-app notes show page title only when distinct.
    var sourcePillSubtitle: String? {
        if let path = sourceVaultRelativePath {
            if path.contains("/") { return path }
            let primary = sourcePillPrimary
            if path.caseInsensitiveCompare(primary) != .orderedSame {
                return path
            }
        }

        let title = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        let primary = sourcePillPrimary
        if !title.isEmpty,
           title != primary,
           !SourceDisplayName.looksLikeFilesystemPath(title) {
            return title
        }
        return nil
    }

    /// Normalized vault-relative path (`pages/Welcome.md`) when the chunk was indexed from markdown.
    var sourceVaultRelativePath: String? {
        guard let raw = sourceFilename?.trimmingCharacters(in: .whitespacesAndNewlines), !raw.isEmpty else {
            return nil
        }
        return raw.replacingOccurrences(of: "\\", with: "/")
    }

    /// Short excerpt for pill hover / help — not shown as the pill subtitle.
    var sourcePillExcerpt: String? {
        let excerpt = snippet
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\n", with: " ")
        guard !excerpt.isEmpty else { return nil }
        let maxChars = 120
        if excerpt.count <= maxChars { return excerpt }
        return String(excerpt.prefix(maxChars - 1)).trimmingCharacters(in: .whitespaces) + "…"
    }

    /// Chunk index label when multiple slices from the same file were retrieved.
    var sourcePillChunkLabel: String? {
        guard chunkIndex > 0 else { return nil }
        return "chunk \(chunkIndex + 1)"
    }

    /// Backward-compatible single-line label (RAG prompt headers).
    var sourcePillTitle: String {
        sourcePillPrimary
    }

    /// Drops hits with no resolvable label.
    var isValidSourcePill: Bool {
        let label = sourcePillPrimary
        guard !label.isEmpty, label != "Untitled" else { return false }
        return !SourceDisplayName.looksLikeFilesystemPath(label)
    }
}
