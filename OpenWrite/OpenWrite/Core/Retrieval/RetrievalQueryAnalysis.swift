import Foundation

/// Lightweight query understanding for note-index hybrid search (no LLM).
enum RetrievalQueryAnalysis: Sendable {
    struct Result: Sendable {
        let sanitizedQuery: String
        let isTemporal: Bool
        let expandedTokens: [String]
    }

    private static let temporalMarkers = [
        "yesterday", "today", "tonight", "last week", "last month", "this week",
        "recent", "latest", "news", "daily", "what happened", "when did"
    ]

    static func analyze(_ query: String) -> Result {
        let lower = query.lowercased()
        let isTemporal = temporalMarkers.contains { lower.contains($0) }
        let base = TextChunker.keywordTokens(from: query)
        let expanded = VaultQueryExpander.expandedTokens(from: query, base: base)
        return Result(
            sanitizedQuery: query,
            isTemporal: isTemporal,
            expandedTokens: expanded
        )
    }
}

/// Local query expansion (filename stems, hyphen splits) — mirrors web follow-up expansion in spirit.
enum VaultQueryExpander: Sendable {
    static func expandedTokens(from query: String, base: [String]) -> [String] {
        var seen = Set<String>()
        var tokens: [String] = []

        func append(_ raw: String) {
            let token = raw.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
            guard token.count > 2, !seen.contains(token) else { return }
            seen.insert(token)
            tokens.append(token)
        }

        for token in base { append(token) }

        let lower = query.lowercased()
        if let filename = extractFilenameStem(from: lower) {
            append(filename)
        }

        for token in base {
            for piece in token.split(whereSeparator: { $0 == "-" || $0 == "_" }) {
                append(String(piece))
            }
        }

        // Wikilink-style `[[Note Title]]` in the query.
        if let regex = try? NSRegularExpression(pattern: #"\[\[([^\]]+)\]\]"#) {
            let range = NSRange(query.startIndex..., in: query)
            for match in regex.matches(in: query, range: range) {
                guard match.numberOfRanges > 1,
                      let capture = Range(match.range(at: 1), in: query) else { continue }
                for word in query[capture].split(whereSeparator: { !$0.isLetter && !$0.isNumber }) {
                    append(String(word))
                }
            }
        }

        return tokens
    }

    private static func extractFilenameStem(from lower: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: #"([\w-]+)\.md\b"#) else { return nil }
        let range = NSRange(lower.startIndex..., in: lower)
        guard let match = regex.firstMatch(in: lower, range: range),
              let capture = Range(match.range(at: 1), in: lower) else { return nil }
        return String(lower[capture])
    }
}

/// Keeps top-k from dominating a single long note (MMR-lite: best score per document first).
enum RetrievalDiversity: Sendable {
    static func capPerDocument(
        _ candidates: [HybridRankCandidate],
        limit: Int,
        maxPerDocument: Int = 2
    ) -> [HybridRankCandidate] {
        guard limit > 0, maxPerDocument > 0 else { return [] }
        var perDoc: [UUID: Int] = [:]
        var selected: [HybridRankCandidate] = []
        selected.reserveCapacity(limit)

        for candidate in candidates.sorted(by: { $0.combinedScore > $1.combinedScore }) {
            let docID = candidate.chunk.documentID
            let used = perDoc[docID, default: 0]
            guard used < maxPerDocument else { continue }
            perDoc[docID] = used + 1
            selected.append(candidate)
            if selected.count >= limit { break }
        }
        return selected
    }

    static func applyRecencyBoost(
        _ candidates: [HybridRankCandidate],
        isTemporal: Bool,
        now: Date = Date()
    ) -> [HybridRankCandidate] {
        guard isTemporal else { return candidates }
        return candidates.map { candidate in
            guard let updated = candidate.chunk.documentUpdatedAt else { return candidate }
            let ageDays = max(0, now.timeIntervalSince(updated) / 86_400)
            let freshness = max(0, 1 - ageDays / 30)
            var boosted = candidate
            boosted.combinedScore += freshness * AISafetyLimits.recencyBoostWeight
            boosted.combinedScore = min(1, boosted.combinedScore)
            return boosted
        }
        .sorted { $0.combinedScore > $1.combinedScore }
    }
}
