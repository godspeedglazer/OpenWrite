import Foundation

/// One logical document fed into the ingestion pipeline (in-app page or on-disk `.md`).
struct VaultIndexEntry: Sendable {
    let documentID: UUID
    let title: String
    let blocks: [NoteBlock]
    let sourceFilename: String?
    /// Page or file modification time — embedded in chunk text for time-relative RAG.
    let documentUpdatedAt: Date?
}
