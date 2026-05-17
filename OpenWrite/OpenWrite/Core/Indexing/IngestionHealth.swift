// SPDX-License-Identifier: MIT
//
// Ingestion health and progress reporting — patterns inspired by rem-main `IngestionHealth.swift`
// (screen-capture fields omitted; vault indexing status only).

import Foundation
import Combine

/// High-level phase of the vault AI ingestion pipeline.
enum IngestionStatus: String, Codable, Sendable, Equatable {
    case idle
    case watching
    case parsing
    case chunking
    case embedding
    case storing
    case rebuilding
    case cancelled
    case failed
}

/// Snapshot of ingestion state for UI and persistence.
struct IngestionHealth: Equatable, Sendable {
    var status: IngestionStatus = .idle
    var lastError: String?
    var lastCompletedAt: Date?
    var documentsTotal: Int = 0
    var documentsCompleted: Int = 0
    var chunksTotal: Int = 0
    var chunksCompleted: Int = 0
    var pendingFSEventPaths: Int = 0
    var indexedChunkCount: Int = 0

    var progressFraction: Double {
        if chunksTotal > 0 {
            return min(1, Double(chunksCompleted) / Double(chunksTotal))
        }
        if documentsTotal > 0 {
            return min(1, Double(documentsCompleted) / Double(documentsTotal))
        }
        return status == .idle || status == .cancelled ? 0 : 0
    }

    var isActive: Bool {
        switch status {
        case .idle, .cancelled, .failed:
            return false
        case .watching, .parsing, .chunking, .embedding, .storing, .rebuilding:
            return true
        }
    }

    var statusLabel: String {
        switch status {
        case .idle: return "Idle"
        case .watching: return "Watching vault"
        case .parsing: return "Parsing NDL"
        case .chunking: return "Chunking"
        case .embedding: return "Embedding"
        case .storing: return "Storing vectors"
        case .rebuilding: return "Rebuilding index"
        case .cancelled: return "Cancelled"
        case .failed: return "Failed"
        }
    }

    var progressSummary: String? {
        guard isActive else { return nil }
        if chunksTotal > 0 {
            return "\(chunksCompleted)/\(chunksTotal) chunks"
        }
        if documentsTotal > 0 {
            return "\(documentsCompleted)/\(documentsTotal) pages"
        }
        return statusLabel
    }
}

@MainActor
final class IngestionHealthMonitor: ObservableObject {
    static let lastErrorDefaultsKey = "openwrite.ingestion.lastError"

    @Published private(set) var health = IngestionHealth()

    init() {
        health.lastError = UserDefaults.standard.string(forKey: Self.lastErrorDefaultsKey)
    }

    func reloadFromPersistence() {
        health.lastError = UserDefaults.standard.string(forKey: Self.lastErrorDefaultsKey)
    }

    func setStatus(_ status: IngestionStatus) {
        health.status = status
        if status != .failed, status != .cancelled {
            health.lastError = nil
            UserDefaults.standard.removeObject(forKey: Self.lastErrorDefaultsKey)
        }
    }

    func recordError(_ message: String) {
        health.status = .failed
        health.lastError = message
        UserDefaults.standard.set(message, forKey: Self.lastErrorDefaultsKey)
    }

    func clearError() {
        health.lastError = nil
        UserDefaults.standard.removeObject(forKey: Self.lastErrorDefaultsKey)
        if health.status == .failed {
            health.status = .idle
        }
    }

    func beginRebuild(documentCount: Int) {
        health.status = .rebuilding
        health.documentsTotal = documentCount
        health.documentsCompleted = 0
        health.chunksTotal = 0
        health.chunksCompleted = 0
        health.lastError = nil
    }

    func beginDocumentIngest(chunkCount: Int, isRebuild: Bool) {
        health.chunksTotal = chunkCount
        health.chunksCompleted = 0
        health.status = isRebuild ? .rebuilding : .chunking
    }

    func setPhase(_ status: IngestionStatus) {
        health.status = status
    }

    func advanceDocument() {
        health.documentsCompleted += 1
    }

    func advanceChunk() {
        health.chunksCompleted += 1
    }

    func setPendingFSEvents(_ count: Int) {
        health.pendingFSEventPaths = count
    }

    func markCancelled() {
        health.status = .cancelled
    }

    func markCompleted(indexedChunks: Int) {
        health.status = .idle
        health.lastCompletedAt = .now
        health.indexedChunkCount = indexedChunks
        health.documentsTotal = 0
        health.documentsCompleted = 0
        health.chunksTotal = 0
        health.chunksCompleted = 0
        health.pendingFSEventPaths = 0
        health.lastError = nil
        UserDefaults.standard.removeObject(forKey: Self.lastErrorDefaultsKey)
    }

    func markWatching() {
        health.status = .watching
    }

    func updateIndexedChunkCount(_ count: Int) {
        health.indexedChunkCount = count
    }
}
