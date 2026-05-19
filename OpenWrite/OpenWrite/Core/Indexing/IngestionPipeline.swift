// SPDX-License-Identifier: AGPL-3.0-or-later
//
// Vault ingestion orchestrator: FSEvents stub → parse NDL → chunk (Reor port) → embed → vector store.
// Chunking behavior from Reor `electron/main/common/chunking.ts` via `TextChunker` — see ReorPortNotes.md.

import Foundation

enum IngestionPipelineError: LocalizedError, Sendable {
    case cancelled
    case parseFailed(String)
    case fileReadFailed(URL)

    var errorDescription: String? {
        switch self {
        case .cancelled:
            return "Indexing was cancelled."
        case .parseFailed(let detail):
            return "NDL parse failed: \(detail)"
        case .fileReadFailed(let url):
            return "Could not read \(url.lastPathComponent)."
        }
    }
}

/// End-to-end vault document ingestion for semantic search.
actor IngestionPipeline {
    let vectorStore: InMemoryVectorStore
    let embeddings: EmbeddingService
    let fsevents: VaultFSEventsStub

    /// MainActor monitor; `nonisolated(unsafe)` so ingestion stages can report progress from this actor.
    nonisolated(unsafe) private weak var health: IngestionHealthMonitor?
    private var cancelRequested = false

    init(
        vectorStore: InMemoryVectorStore,
        embeddings: EmbeddingService,
        health: IngestionHealthMonitor? = nil,
        fsevents: VaultFSEventsStub = VaultFSEventsStub()
    ) {
        self.vectorStore = vectorStore
        self.embeddings = embeddings
        self.health = health
        self.fsevents = fsevents
    }

    nonisolated func attachHealth(_ monitor: IngestionHealthMonitor) {
        health = monitor
    }

    func cancel() {
        cancelRequested = true
        let monitor = health
        Task { @MainActor in
            monitor?.markCancelled()
        }
    }

    private func withHealth(_ update: @MainActor @Sendable (IngestionHealthMonitor) -> Void) async {
        guard let monitor = health else { return }
        await MainActor.run {
            update(monitor)
        }
    }

    func resetCancel() {
        cancelRequested = false
    }

    // MARK: - FSEvents stub path

    func startFilesystemWatch(roots: [URL] = []) async {
        await fsevents.configureWatchRoots(roots)
        await fsevents.startWatching()
        await withHealth { $0.markWatching() }
    }

    func processPendingFilesystemEvents(
        defaultPageType: PageType = .note
    ) async throws {
        let paths = await fsevents.drainPending()
        await withHealth { $0.setPendingFSEvents(0) }
        guard !paths.isEmpty else { return }

        for path in paths {
            try Task.checkCancellation()
            try throwIfCancelled()
            if path.pathExtension.lowercased() == "md" {
                _ = try await ingestMarkdownFile(at: path)
            } else {
                _ = try await ingestNDLFile(at: path, defaultPageType: defaultPageType)
            }
        }
    }

    /// Parses markdown from disk and indexes with a stable document id and filename citation.
    @discardableResult
    func ingestMarkdownFile(
        at url: URL,
        vaultRoot: URL? = nil
    ) async throws -> UUID {
        try throwIfCancelled()
        await withHealth { $0.setPhase(.parsing) }

        let source: String
        do {
            source = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw IngestionPipelineError.fileReadFailed(url)
        }

        let root = vaultRoot ?? VaultLocationPreferences.resolvedVaultRootURL()
        let relative = relativeMarkdownPath(for: url, vaultRoot: root) ?? url.lastPathComponent
        let title = url.deletingPathExtension().lastPathComponent
        let documentID = VaultMarkdownCatalog.stableDocumentID(relativePath: relative)
        let blocks = MarkdownImporter().importString(source)

        let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate)
        try await ingest(
            documentID: documentID,
            title: title,
            blocks: blocks,
            sourceFilename: relative,
            documentUpdatedAt: modified,
            isRebuild: false
        )
        return documentID
    }

    /// Full scan of vault markdown files (Reor-style `.md` discovery).
    func ingestAllMarkdownFiles(vaultRoot: URL) async throws -> Int {
        let files = VaultMarkdownCatalog.scan(vaultRoot: vaultRoot)
        var ingested = 0
        for file in files {
            try Task.checkCancellation()
            try throwIfCancelled()
            let blocks = try VaultMarkdownCatalog.loadBlocks(from: file)
            try await ingest(
                documentID: file.documentID,
                title: file.title,
                blocks: blocks,
                sourceFilename: file.sourceFilename,
                documentUpdatedAt: file.modifiedAt,
                isRebuild: false
            )
            ingested += 1
        }
        return ingested
    }

    private func relativeMarkdownPath(for fileURL: URL, vaultRoot: URL) -> String? {
        let root = vaultRoot.standardizedFileURL
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        let path = fileURL.standardizedFileURL.path
        guard path.hasPrefix(rootPath) else { return nil }
        return String(path.dropFirst(rootPath.count))
    }

    /// Reads NDL from disk, parses, and indexes as a standalone document (import folder MVP).
    @discardableResult
    func ingestNDLFile(
        at url: URL,
        documentID: UUID = UUID(),
        title: String? = nil,
        defaultPageType: PageType = .note
    ) async throws -> UUID {
        try throwIfCancelled()
        await withHealth { $0.setPhase(.parsing) }

        let source: String
        do {
            source = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw IngestionPipelineError.fileReadFailed(url)
        }

        let resolvedTitle = title ?? url.deletingPathExtension().lastPathComponent
        let parsed = NDLParser.parseDocument(
            source: source,
            pageType: defaultPageType,
            title: resolvedTitle
        )

        try await ingest(
            documentID: documentID,
            title: resolvedTitle,
            blocks: parsed.bodyBlocks,
            sourceFilename: nil,
            isRebuild: false
        )
        return documentID
    }

    // MARK: - In-memory vault documents

    func ingest(
        documentID: UUID,
        title: String,
        blocks: [NoteBlock],
        sourceFilename: String? = nil,
        documentUpdatedAt: Date? = nil,
        isRebuild: Bool
    ) async throws {
        do {
            try throwIfCancelled()
            await vectorStore.remove(documentID: documentID)

            await withHealth { $0.setPhase(.chunking) }
            let chunks = TextChunker.chunks(
                documentID: documentID,
                title: title,
                blocks: blocks,
                sourceFilename: sourceFilename,
                documentUpdatedAt: documentUpdatedAt
            )
            guard !chunks.isEmpty else { return }

            await withHealth { $0.beginDocumentIngest(chunkCount: chunks.count, isRebuild: isRebuild) }

            for chunk in chunks {
                try Task.checkCancellation()
                try throwIfCancelled()

                await withHealth { $0.setPhase(.embedding) }
                let vector = try await embeddings.embed(text: chunk.text)

                try throwIfCancelled()
                await withHealth { $0.setPhase(.storing) }
                await vectorStore.upsert(chunk: chunk, vector: vector)

                await withHealth { $0.advanceChunk() }
            }
        } catch {
            if error is CancellationError {
                await withHealth { $0.markCancelled() }
            } else if let pipelineError = error as? IngestionPipelineError, case .cancelled = pipelineError {
                await withHealth { $0.markCancelled() }
            } else {
                await withHealth { $0.recordError(error.localizedDescription) }
            }
            throw error
        }
    }

    func remove(documentID: UUID) async {
        await vectorStore.remove(documentID: documentID)
        let count = await vectorStore.chunkCount
        await withHealth { $0.updateIndexedChunkCount(count) }
    }

    func rebuildAll(entries: [VaultIndexEntry]) async throws {
        resetCancel()
        await withHealth { $0.beginRebuild(documentCount: entries.count) }

        await vectorStore.reset()

        for entry in entries {
            try Task.checkCancellation()
            try throwIfCancelled()

            try await ingest(
                documentID: entry.documentID,
                title: entry.title,
                blocks: entry.blocks,
                sourceFilename: entry.sourceFilename,
                documentUpdatedAt: entry.documentUpdatedAt,
                isRebuild: true
            )

            await withHealth { $0.advanceDocument() }
        }

        let count = await vectorStore.chunkCount
        await vectorStore.flushPersistedIndex()
        await withHealth { $0.markCompleted(indexedChunks: count) }
    }

    private func throwIfCancelled() throws {
        if cancelRequested || Task.isCancelled {
            throw IngestionPipelineError.cancelled
        }
    }
}
