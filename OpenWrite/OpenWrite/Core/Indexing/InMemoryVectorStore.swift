import Foundation

struct VectorSearchResult: Sendable {
    let chunkID: UUID
    let score: Double
}

/// MVP in-memory vector index with cosine similarity.
actor InMemoryVectorStore {
    private var chunksByID: [UUID: IndexChunk] = [:]
    private var vectorsByID: [UUID: [Float]] = [:]

    var chunkCount: Int { chunksByID.count }

    func reset() {
        chunksByID.removeAll()
        vectorsByID.removeAll()
    }

    func upsert(chunk: IndexChunk, vector: [Float]) {
        chunksByID[chunk.id] = chunk
        vectorsByID[chunk.id] = vector
    }

    func remove(documentID: UUID) {
        let ids = chunksByID.values.filter { $0.documentID == documentID }.map(\.id)
        for id in ids {
            chunksByID.removeValue(forKey: id)
            vectorsByID.removeValue(forKey: id)
        }
    }

    func chunk(id: UUID) -> IndexChunk? {
        chunksByID[id]
    }

    func allChunks() -> [IndexChunk] {
        Array(chunksByID.values)
    }

    func search(queryVector: [Float], limit: Int) -> [VectorSearchResult] {
        guard !queryVector.isEmpty, limit > 0 else { return [] }

        var scored: [VectorSearchResult] = []
        scored.reserveCapacity(vectorsByID.count)

        for (id, vector) in vectorsByID {
            let similarity = Self.cosineSimilarity(queryVector, vector)
            scored.append(VectorSearchResult(chunkID: id, score: similarity))
        }

        return scored
            .sorted { $0.score > $1.score }
            .prefix(limit)
            .map { $0 }
    }

    static func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0 }
        var dot: Float = 0
        var normA: Float = 0
        var normB: Float = 0
        for i in 0 ..< a.count {
            dot += a[i] * b[i]
            normA += a[i] * a[i]
            normB += b[i] * b[i]
        }
        let denom = sqrt(normA) * sqrt(normB)
        guard denom > 0 else { return 0 }
        return Double(dot / denom)
    }
}
