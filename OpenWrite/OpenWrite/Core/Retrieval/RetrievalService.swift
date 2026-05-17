import Foundation

struct RetrievalHit: Identifiable, Hashable, Sendable {
    let id: UUID
    let documentID: UUID
    let blockID: UUID?
    let score: Double
    let snippet: String
}

/// Orchestrates hybrid search over indexed vault content (major ride stub).
protocol RetrievalService: Sendable {
    func search(query: String, limit: Int) async throws -> [RetrievalHit]
}

struct NoOpRetrievalService: RetrievalService {
    func search(query: String, limit: Int) async throws -> [] {
        _ = query
        _ = limit
        return []
    }
}
