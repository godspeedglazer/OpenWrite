// SPDX-License-Identifier: AGPL-3.0-or-later
//
// MVP in-memory vector index with cosine similarity.
// Persistence stub: JSON snapshot under Application Support (Reor vector-database shape, Swift-only).

import Foundation

struct VectorSearchResult: Sendable {
    let chunkID: UUID
    let score: Double
}

private struct PersistedVectorIndex: Codable, Sendable {
    var version: Int
    var chunks: [PersistedChunkRecord]
}

private struct PersistedChunkRecord: Codable, Sendable {
    var id: UUID
    var documentID: UUID
    var documentTitle: String
    var blockID: UUID?
    var chunkIndex: Int
    var text: String
    var vector: [Float]
}

enum VectorStorePersistence {
    static let subdirectory = "OpenWrite"
    static let filename = "vector_index.json"
    static let formatVersion = 1

    static var defaultURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent(subdirectory, isDirectory: true)
            .appendingPathComponent(filename)
    }
}

/// MVP in-memory vector index with cosine similarity and JSON persistence stub.
actor InMemoryVectorStore {
    private var chunksByID: [UUID: IndexChunk] = [:]
    private var vectorsByID: [UUID: [Float]] = [:]
    private let persistenceURL: URL
    private var persistenceEnabled: Bool

    init(persistenceURL: URL = VectorStorePersistence.defaultURL) {
        self.persistenceURL = persistenceURL
        self.persistenceEnabled = true
    }

    var chunkCount: Int { chunksByID.count }

    func setPersistenceEnabled(_ enabled: Bool) {
        persistenceEnabled = enabled
    }

    func reset() {
        chunksByID.removeAll()
        vectorsByID.removeAll()
        persistToDisk()
    }

    func upsert(chunk: IndexChunk, vector: [Float]) {
        chunksByID[chunk.id] = chunk
        vectorsByID[chunk.id] = vector
        persistToDisk()
    }

    func remove(documentID: UUID) {
        let ids = chunksByID.values.filter { $0.documentID == documentID }.map(\.id)
        for id in ids {
            chunksByID.removeValue(forKey: id)
            vectorsByID.removeValue(forKey: id)
        }
        persistToDisk()
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

    func loadFromDiskIfPresent() {
        guard FileManager.default.fileExists(atPath: persistenceURL.path) else { return }
        do {
            let data = try Data(contentsOf: persistenceURL)
            let decoded = try JSONDecoder().decode(PersistedVectorIndex.self, from: data)
            guard decoded.version == VectorStorePersistence.formatVersion else { return }
            chunksByID.removeAll()
            vectorsByID.removeAll()
            for record in decoded.chunks {
                let chunk = IndexChunk(
                    id: record.id,
                    documentID: record.documentID,
                    documentTitle: record.documentTitle,
                    blockID: record.blockID,
                    chunkIndex: record.chunkIndex,
                    text: record.text
                )
                chunksByID[record.id] = chunk
                vectorsByID[record.id] = record.vector
            }
        } catch {
            // MVP: ignore corrupt snapshots; in-memory index rebuilds from vault.
        }
    }

    private func persistToDisk() {
        guard persistenceEnabled else { return }
        let records = chunksByID.values.sorted { $0.id.uuidString < $1.id.uuidString }.map { chunk -> PersistedChunkRecord in
            PersistedChunkRecord(
                id: chunk.id,
                documentID: chunk.documentID,
                documentTitle: chunk.documentTitle,
                blockID: chunk.blockID,
                chunkIndex: chunk.chunkIndex,
                text: chunk.text,
                vector: vectorsByID[chunk.id] ?? []
            )
        }
        let payload = PersistedVectorIndex(version: VectorStorePersistence.formatVersion, chunks: records)
        do {
            let dir = persistenceURL.deletingLastPathComponent()
            try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            let data = try JSONEncoder().encode(payload)
            try data.write(to: persistenceURL, options: .atomic)
        } catch {
            // MVP stub: silent failure; health monitor surfaces ingest errors separately.
        }
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
