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
    var sourceFilename: String?
    var blockID: UUID?
    var chunkIndex: Int
    var text: String
    var vector: [Float]
}

enum VectorStorePersistence {
    static let subdirectory = "openwrite"
    static let filename = "index.json"
    static let legacySubdirectory = "OpenWrite"
    static let legacyFilename = "vector_index.json"
    static let formatVersion = 2

    private static var applicationSupportBase: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
    }

    static var defaultURL: URL {
        applicationSupportBase
            .appendingPathComponent(subdirectory, isDirectory: true)
            .appendingPathComponent(filename)
    }

    static var legacyURL: URL {
        applicationSupportBase
            .appendingPathComponent(legacySubdirectory, isDirectory: true)
            .appendingPathComponent(legacyFilename)
    }
}

/// MVP in-memory vector index with cosine similarity and JSON persistence.
actor InMemoryVectorStore {
    private var chunksByID: [UUID: IndexChunk] = [:]
    private var vectorsByID: [UUID: [Float]] = [:]
    private let persistenceURL: URL
    private var persistenceEnabled: Bool
    private var persistDebounceTask: Task<Void, Never>?
    private static let persistDebounceNanoseconds: UInt64 = 2_000_000_000

    /// MainActor monitor; reports load/save failures into the rail footer.
    nonisolated(unsafe) private weak var health: IngestionHealthMonitor?

    init(persistenceURL: URL = VectorStorePersistence.defaultURL) {
        self.persistenceURL = persistenceURL
        self.persistenceEnabled = true
    }

    nonisolated func attachHealth(_ monitor: IngestionHealthMonitor) {
        health = monitor
    }

    var chunkCount: Int { chunksByID.count }

    func setPersistenceEnabled(_ enabled: Bool) {
        persistenceEnabled = enabled
    }

    func reset() {
        chunksByID.removeAll()
        vectorsByID.removeAll()
        schedulePersistToDisk()
    }

    func upsert(chunk: IndexChunk, vector: [Float]) {
        chunksByID[chunk.id] = chunk
        vectorsByID[chunk.id] = vector
        schedulePersistToDisk()
    }

    func remove(documentID: UUID) {
        let ids = chunksByID.values.filter { $0.documentID == documentID }.map(\.id)
        for id in ids {
            chunksByID.removeValue(forKey: id)
            vectorsByID.removeValue(forKey: id)
        }
        schedulePersistToDisk()
    }

    /// Writes the index immediately (end of rebuild or explicit flush).
    func flushPersistedIndex() {
        persistDebounceTask?.cancel()
        persistDebounceTask = nil
        writeIndexToDisk()
    }

    private func schedulePersistToDisk() {
        guard persistenceEnabled else { return }
        persistDebounceTask?.cancel()
        persistDebounceTask = Task {
            try? await Task.sleep(nanoseconds: Self.persistDebounceNanoseconds)
            guard !Task.isCancelled else { return }
            writeIndexToDisk()
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

    func loadFromDiskIfPresent() {
        if loadSnapshot(from: persistenceURL) {
            return
        }
            if loadSnapshot(from: VectorStorePersistence.legacyURL) {
            flushPersistedIndex()
        }
    }

    @discardableResult
    private func loadSnapshot(from url: URL) -> Bool {
        guard FileManager.default.fileExists(atPath: url.path) else { return false }
        do {
            let data = try Data(contentsOf: url)
            let decoded = try JSONDecoder().decode(PersistedVectorIndex.self, from: data)
            guard decoded.version == 1 || decoded.version == VectorStorePersistence.formatVersion else {
                reportPersistenceFailure(
                    "Index format is unsupported. Use Rebuild index in Settings."
                )
                return false
            }
            chunksByID.removeAll()
            vectorsByID.removeAll()
            for record in decoded.chunks {
                let chunk = IndexChunk(
                    id: record.id,
                    documentID: record.documentID,
                    documentTitle: record.documentTitle,
                    sourceFilename: record.sourceFilename,
                    blockID: record.blockID,
                    chunkIndex: record.chunkIndex,
                    text: record.text
                )
                chunksByID[record.id] = chunk
                vectorsByID[record.id] = record.vector
            }
            return true
        } catch {
            reportPersistenceFailure(
                "Could not load saved index (\(url.lastPathComponent)). Rebuild index in Settings."
            )
            return false
        }
    }

    private func writeIndexToDisk() {
        guard persistenceEnabled else { return }
        let records = chunksByID.values.sorted { $0.id.uuidString < $1.id.uuidString }.map { chunk -> PersistedChunkRecord in
            PersistedChunkRecord(
                id: chunk.id,
                documentID: chunk.documentID,
                documentTitle: chunk.documentTitle,
                sourceFilename: chunk.sourceFilename,
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
            reportPersistenceFailure("Could not save index: \(error.localizedDescription)")
        }
    }

    private func reportPersistenceFailure(_ message: String) {
        let monitor = health
        Task { @MainActor in
            monitor?.recordError(message)
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
