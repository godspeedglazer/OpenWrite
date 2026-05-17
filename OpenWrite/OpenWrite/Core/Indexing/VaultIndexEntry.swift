import Foundation

/// One logical document fed into the ingestion pipeline (in-app page or on-disk `.md`).
struct VaultIndexEntry: Sendable {
    let documentID: UUID
    let title: String
    let blocks: [NoteBlock]
    let sourceFilename: String?
}
