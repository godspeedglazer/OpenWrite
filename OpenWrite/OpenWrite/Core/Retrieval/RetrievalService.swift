import Foundation

struct RetrievalHit: Identifiable, Hashable, Sendable {
    let id: UUID
    let documentID: UUID
    let documentTitle: String
    let sourceFilename: String?
    let blockID: UUID?
    let chunkIndex: Int
    let score: Double
    let snippet: String

    init(chunk: IndexChunk, score: Double) {
        self.id = chunk.id
        self.documentID = chunk.documentID
        self.documentTitle = chunk.documentTitle
        self.sourceFilename = chunk.sourceFilename
        self.blockID = chunk.blockID
        self.chunkIndex = chunk.chunkIndex
        self.score = score
        self.snippet = AIInput.sanitizeSnippet(chunk.text, maxChars: AISafetyLimits.maxSnippetCharsPerChunk)
    }

    /// Synthetic hit for a chat file attachment (not in the vector index).
    init(attachmentID: UUID, filename: String, snippet: String) {
        self.id = attachmentID
        self.documentID = attachmentID
        self.documentTitle = filename
        self.sourceFilename = filename
        self.blockID = nil
        self.chunkIndex = 0
        self.score = 1.0
        self.snippet = snippet
    }
}

/// Orchestrates hybrid search over indexed vault content.
protocol RetrievalService: Sendable {
    func search(query: String, limit: Int) async throws -> [RetrievalHit]
    func related(to documentID: UUID, limit: Int) async throws -> [RetrievalHit]
}

struct HybridRetrievalService: RetrievalService {
    let vectorStore: InMemoryVectorStore
    let embeddings: EmbeddingService
    let ranker: HybridRanker

    init(
        vectorStore: InMemoryVectorStore,
        embeddings: EmbeddingService,
        ranker: HybridRanker = HybridRanker()
    ) {
        self.vectorStore = vectorStore
        self.embeddings = embeddings
        self.ranker = ranker
    }

    func search(query: String, limit: Int) async throws -> [RetrievalHit] {
        guard let sanitized = AIInput.sanitizeQuery(query) else { return [] }
        let pool = max(limit, AISafetyLimits.prefilterCandidateCount)

        let queryVector = try await embeddings.embed(text: sanitized)
        let vectorResults = await vectorStore.search(queryVector: queryVector, limit: pool)

        var vectorHits: [(chunk: IndexChunk, score: Double)] = []
        for result in vectorResults {
            if let chunk = await vectorStore.chunk(id: result.chunkID) {
                vectorHits.append((chunk, result.score))
            }
        }

        let vectorPool = vectorHits.map(\.chunk)
        let keywordHits = ranker.keywordHits(query: sanitized, in: vectorPool, limit: pool)

        let ranked = ranker.rank(vectorHits: vectorHits, keywordHits: keywordHits, limit: limit)
        return ranked.map { RetrievalHit(chunk: $0.chunk, score: $0.combinedScore) }
    }

    func related(to documentID: UUID, limit: Int) async throws -> [RetrievalHit] {
        let chunks = await vectorStore.allChunks().filter { $0.documentID == documentID }
        guard let seed = chunks.first else { return [] }
        let queryText = chunks.map(\.text).joined(separator: "\n")
        let hits = try await search(query: queryText.isEmpty ? seed.documentTitle : queryText, limit: limit + 4)
        return hits
            .filter { $0.documentID != documentID }
            .prefix(limit)
            .map { $0 }
    }
}

struct NoOpRetrievalService: RetrievalService {
    func search(query: String, limit: Int) async throws -> [RetrievalHit] {
        _ = query
        _ = limit
        return []
    }

    func related(to documentID: UUID, limit: Int) async throws -> [RetrievalHit] {
        _ = documentID
        _ = limit
        return []
    }
}
