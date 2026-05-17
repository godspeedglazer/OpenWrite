import Foundation

/// Indexes vault documents for lexical and semantic retrieval.
protocol IndexerService: Sendable {
    func index(
        documentID: UUID,
        title: String,
        blocks: [NoteBlock],
        sourceFilename: String?
    ) async throws
    func remove(documentID: UUID) async throws
    func rebuildAll(entries: [VaultIndexEntry]) async throws
    func cancel() async
}

/// Indexes via `IngestionPipeline` with cooperative cancellation and health reporting.
struct PipelineIndexerService: IndexerService {
    let pipeline: IngestionPipeline

    func index(
        documentID: UUID,
        title: String,
        blocks: [NoteBlock],
        sourceFilename: String?
    ) async throws {
        try await pipeline.ingest(
            documentID: documentID,
            title: title,
            blocks: blocks,
            sourceFilename: sourceFilename,
            isRebuild: false
        )
    }

    func remove(documentID: UUID) async throws {
        await pipeline.remove(documentID: documentID)
    }

    func rebuildAll(entries: [VaultIndexEntry]) async throws {
        try await pipeline.rebuildAll(entries: entries)
    }

    func cancel() async {
        await pipeline.cancel()
    }
}

/// Direct in-memory indexer (legacy / tests) without pipeline health stages.
struct InMemoryIndexerService: IndexerService {
    let vectorStore: InMemoryVectorStore
    let embeddings: EmbeddingService

    func index(
        documentID: UUID,
        title: String,
        blocks: [NoteBlock],
        sourceFilename: String?
    ) async throws {
        await vectorStore.remove(documentID: documentID)
        let chunks = TextChunker.chunks(
            documentID: documentID,
            title: title,
            blocks: blocks,
            sourceFilename: sourceFilename
        )
        for chunk in chunks {
            let vector = try await embeddings.embed(text: chunk.text)
            await vectorStore.upsert(chunk: chunk, vector: vector)
        }
    }

    func remove(documentID: UUID) async throws {
        await vectorStore.remove(documentID: documentID)
    }

    func rebuildAll(entries: [VaultIndexEntry]) async throws {
        await vectorStore.reset()
        for entry in entries {
            try await index(
                documentID: entry.documentID,
                title: entry.title,
                blocks: entry.blocks,
                sourceFilename: entry.sourceFilename
            )
        }
    }

    func cancel() async {}
}

/// No-op indexer for tests.
struct NoOpIndexerService: IndexerService {
    func index(
        documentID: UUID,
        title: String,
        blocks: [NoteBlock],
        sourceFilename: String?
    ) async throws {
        _ = documentID
        _ = title
        _ = blocks
        _ = sourceFilename
    }

    func remove(documentID: UUID) async throws {
        _ = documentID
    }

    func rebuildAll(entries: [VaultIndexEntry]) async throws {
        _ = entries
    }

    func cancel() async {}
}
