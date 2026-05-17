import Foundation

struct HybridRankCandidate: Sendable {
    let chunk: IndexChunk
    var vectorScore: Double
    var keywordScore: Double
    var combinedScore: Double
}

/// Combines lexical and vector scores (Reor `combineAndRankResults` clean-room port).
struct HybridRanker: Sendable {
    var vectorWeight: Double = AISafetyLimits.hybridVectorWeight

    func rank(
        vectorHits: [(chunk: IndexChunk, score: Double)],
        keywordHits: [(chunk: IndexChunk, score: Double)],
        limit: Int
    ) -> [HybridRankCandidate] {
        let keywordWeight = 1 - vectorWeight
        var map: [String: HybridRankCandidate] = [:]

        let maxKeyword = keywordHits.map(\.score).max() ?? 0

        for hit in vectorHits {
            let normalizedVector = max(0, min(1, hit.score))
            map[hit.chunk.fusionKey] = HybridRankCandidate(
                chunk: hit.chunk,
                vectorScore: normalizedVector,
                keywordScore: 0,
                combinedScore: normalizedVector * vectorWeight
            )
        }

        for hit in keywordHits {
            let normalizedKeyword = maxKeyword > 0 ? hit.score / maxKeyword : 0
            let component = normalizedKeyword * keywordWeight
            let key = hit.chunk.fusionKey

            if var existing = map[key] {
                existing.keywordScore = hit.score
                existing.combinedScore += component
                map[key] = existing
            } else {
                map[key] = HybridRankCandidate(
                    chunk: hit.chunk,
                    vectorScore: 0,
                    keywordScore: hit.score,
                    combinedScore: component
                )
            }
        }

        return map.values
            .sorted { $0.combinedScore > $1.combinedScore }
            .prefix(limit)
            .map { $0 }
    }

    func keywordScore(query: String, content: String) -> Double {
        let keywords = TextChunker.keywordTokens(from: query)
        guard !keywords.isEmpty else { return 0 }

        let escaped = keywords.map { NSRegularExpression.escapedPattern(for: $0) }
        let pattern = "\\b(\(escaped.joined(separator: "|")))\\b"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else {
            return 0
        }
        let range = NSRange(content.startIndex..., in: content)
        return Double(regex.numberOfMatches(in: content, range: range))
    }
}
