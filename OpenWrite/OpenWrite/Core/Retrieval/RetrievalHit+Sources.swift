import Foundation

extension Array where Element == RetrievalHit {
    /// One entry per vault document or markdown file, highest-scoring chunk first (Reor source pills).
    func uniqueDocumentSources(limit: Int = 8) -> [RetrievalHit] {
        var seenKeys = Set<String>()
        var result: [RetrievalHit] = []
        result.reserveCapacity(Swift.min(limit, count))

        for hit in self {
            guard hit.isValidSourcePill else { continue }
            let keys = hit.sourceDedupeKeys
            if keys.contains(where: { seenKeys.contains($0) }) { continue }
            keys.forEach { seenKeys.insert($0) }
            result.append(hit)
            if result.count >= limit { break }
        }
        return result
    }
}

extension RetrievalHit {
    /// Keys for deduping the same note indexed as an in-app page and as on-disk markdown.
    var sourceDedupeKeys: [String] {
        var keys: [String] = []
        if let name = sourceFilename?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            let leaf = SourceDisplayName.filename(from: name).lowercased()
            keys.append("file:\(leaf)")
            let stem = (leaf as NSString).deletingPathExtension
            if !stem.isEmpty { keys.append("stem:\(stem)") }
        }
        let label = sourcePillTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if !label.isEmpty {
            keys.append("title:\(label)")
            let stem = (label as NSString).deletingPathExtension
            if stem != label { keys.append("stem:\(stem)") }
        }
        keys.append("doc:\(documentID.uuidString.lowercased())")
        return keys
    }

    /// Display label for source pills — page title when available, never a vault path.
    var sourcePillTitle: String {
        let title = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if !title.isEmpty {
            let cleaned = SourceDisplayName.filename(from: title)
            if !cleaned.isEmpty,
               !SourceDisplayName.looksLikeFilesystemPath(cleaned),
               !looksLikeBareFilename(cleaned) {
                return cleaned
            }
            if !SourceDisplayName.looksLikeFilesystemPath(title) {
                return title
            }
        }

        if let name = sourceFilename?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty {
            let leaf = SourceDisplayName.filename(from: name)
            let withoutExtension = (leaf as NSString).deletingPathExtension
            if !withoutExtension.isEmpty, !SourceDisplayName.looksLikeFilesystemPath(withoutExtension) {
                return withoutExtension
            }
        }

        if !title.isEmpty, !SourceDisplayName.looksLikeFilesystemPath(title) {
            let withoutExtension = (title as NSString).deletingPathExtension
            return withoutExtension.isEmpty ? title : withoutExtension
        }

        return "Untitled"
    }

    /// Drops hits whose labels still resolve to absolute paths (stale index rows).
    var isValidSourcePill: Bool {
        let label = sourcePillTitle
        guard !label.isEmpty, label != "Untitled" else { return false }
        return !SourceDisplayName.looksLikeFilesystemPath(label)
    }

    private func looksLikeBareFilename(_ value: String) -> Bool {
        value.lowercased().hasSuffix(".md") || value.contains("/") || value.contains("\\")
    }
}
