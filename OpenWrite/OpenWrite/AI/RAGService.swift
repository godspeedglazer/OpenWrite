import Foundation

struct RAGContext: Sendable {
    var query: String
    var hits: [RetrievalHit]
}

struct RAGAnswer: Sendable {
    var text: String
    var citations: [RetrievalHit]
}

/// Retrieval-augmented generation over the local vault (major ride stub).
protocol RAGService: Sendable {
    func answer(query: String, limit: Int) async throws -> RAGAnswer
}

struct PlaceholderRAGService: RAGService {
    let retrieval: RetrievalService
    let client: LMStudioClient

    func answer(query: String, limit: Int) async throws -> RAGAnswer {
        let hits = try await retrieval.search(query: query, limit: limit)
        _ = try await client.healthCheck()
        return RAGAnswer(
            text: "",
            citations: hits
        )
    }
}
