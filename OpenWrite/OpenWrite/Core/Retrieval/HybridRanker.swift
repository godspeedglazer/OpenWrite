// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Hybrid ranking adapted from Reor (https://github.com/reorproject/reor)
// `src/lib/db.ts` — `keywordSearch`, `combineAndRankResults`, `hybridSearch`.
// Swift reimplementation only; no TypeScript is linked. If this logic is ever
// extracted into a separately distributed module, keep it under AGPL and
// document dynamic-linking obligations in ReorPortNotes.md.

import Foundation

struct HybridRankCandidate: Sendable {
    let chunk: IndexChunk
    var vectorScore: Double
    var keywordScore: Double
    var combinedScore: Double
}

/// Combines lexical and vector scores (Reor `combineAndRankResults`).
struct HybridRanker: Sendable {
    /// Reor `hybridSearch` default `vectorWeight` (0.7 vector / 0.3 keyword).
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
            let vectorScore = max(0, min(1, hit.score))
            map[hit.chunk.fusionKey] = HybridRankCandidate(
                chunk: hit.chunk,
                vectorScore: vectorScore,
                keywordScore: 0,
                combinedScore: vectorScore * vectorWeight
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
            .map { displayCandidate($0, maxKeywordScore: maxKeyword) }
    }

    /// Reor scores keywords on the vector candidate pool (`keywordSearch` → `database.search` first).
    func keywordHits(
        query: String,
        in pool: [IndexChunk],
        limit: Int
    ) -> [(chunk: IndexChunk, score: Double)] {
        var hits: [(chunk: IndexChunk, score: Double)] = []
        for chunk in pool {
            let score = keywordScore(query: query, content: chunk.text)
            if score > 0 {
                hits.append((chunk, score))
            }
        }
        hits.sort { $0.score > $1.score }
        return Array(hits.prefix(limit))
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

    /// Maps fused score to a 0…1 retrieval score (Reor `_distance = 1 - combinedScore` display path).
    private func displayCandidate(
        _ candidate: HybridRankCandidate,
        maxKeywordScore: Double
    ) -> HybridRankCandidate {
        var updated = candidate
        if vectorWeight == 0 {
            if candidate.keywordScore > 0, maxKeywordScore > 0 {
                updated.combinedScore = candidate.keywordScore / maxKeywordScore
            } else {
                updated.combinedScore = 0.01
            }
        } else {
            updated.combinedScore = max(0, min(1, candidate.combinedScore))
        }
        return updated
    }
}
