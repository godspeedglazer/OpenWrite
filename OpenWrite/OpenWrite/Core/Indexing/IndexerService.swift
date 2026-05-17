import Foundation

/// Indexes vault documents for lexical and semantic retrieval (major ride stub).
protocol IndexerService: Sendable {
    func index(documentID: UUID, blocks: [NoteBlock]) async throws
    func remove(documentID: UUID) async throws
    func rebuildAll(documents: [(id: UUID, blocks: [NoteBlock])]) async throws
}

/// No-op indexer for Phase 1 scaffolding.
struct NoOpIndexerService: IndexerService {
    func index(documentID: UUID, blocks: [NoteBlock]) async throws {}
    func remove(documentID: UUID) async throws {}
    func rebuildAll(documents: [(id: UUID, blocks: [NoteBlock])]) async throws {}
}
