import Foundation

extension Array where Element == RetrievalHit {
    /// One entry per vault document, highest-scoring chunk first (Reor source pills).
    func uniqueDocumentSources(limit: Int = 8) -> [RetrievalHit] {
        var seen = Set<UUID>()
        var result: [RetrievalHit] = []
        result.reserveCapacity(Swift.min(limit, count))
        for hit in self {
            guard seen.insert(hit.documentID).inserted else { continue }
            result.append(hit)
            if result.count >= limit { break }
        }
        return result
    }
}

extension RetrievalHit {
    /// Display label for source pills (note title + optional .md hint).
    var sourcePillTitle: String {
        let trimmed = documentTitle.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { return "Untitled" }
        return trimmed
    }
}
