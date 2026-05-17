import Foundation

/// Combines lexical and vector scores into a single ranking (major ride stub).
struct HybridRanker: Sendable {
    var lexicalWeight: Double = 0.5
    var vectorWeight: Double = 0.5

    func rank(hits: [RetrievalHit]) -> [RetrievalHit] {
        hits.sorted { $0.score > $1.score }
    }
}
