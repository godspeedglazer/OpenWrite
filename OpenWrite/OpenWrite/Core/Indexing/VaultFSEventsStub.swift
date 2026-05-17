// SPDX-License-Identifier: MIT
//
// FSEvents watch stub for external NDL / markdown import folders (E-04).
// Real FSEventStream wiring lands here; MVP queues paths for the ingestion pipeline.

import Foundation

/// Queues filesystem paths for `IngestionPipeline` without a live FSEventStream yet.
actor VaultFSEventsStub {
    private(set) var watchRoots: [URL] = []
    private var pendingPaths: [URL] = []
    private var isWatching = false

    var pendingCount: Int { pendingPaths.count }

    func configureWatchRoots(_ urls: [URL]) {
        watchRoots = urls
    }

    /// MVP: simulate watcher start — marks pipeline as watching.
    func startWatching() {
        isWatching = true
    }

    func stopWatching() {
        isWatching = false
        pendingPaths.removeAll()
    }

    /// Enqueue a changed file (called by importer or future FSEvent callback).
    func enqueueChanged(path: URL) {
        guard isWatching || !watchRoots.isEmpty else { return }
        if !pendingPaths.contains(path) {
            pendingPaths.append(path)
        }
    }

    /// Drain pending paths for processing.
    func drainPending() -> [URL] {
        let batch = pendingPaths
        pendingPaths.removeAll()
        return batch
    }

    func simulatedEvent(at path: URL) {
        enqueueChanged(path: path)
    }
}
