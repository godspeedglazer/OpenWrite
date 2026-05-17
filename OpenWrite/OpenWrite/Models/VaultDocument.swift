import Foundation

/// A single note inside an OpenWrite vault.
struct VaultDocument: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var rootBlocks: [NoteBlock]
    var createdAt: Date
    var updatedAt: Date
    var metadata: [String: String]

    init(
        id: UUID = UUID(),
        title: String,
        rootBlocks: [NoteBlock] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.rootBlocks = rootBlocks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }

    static let welcomeSample = VaultDocument(
        title: "Welcome to OpenWrite",
        rootBlocks: [
            NoteBlock(kind: .heading1, text: "Welcome to OpenWrite"),
            NoteBlock(kind: .paragraph, text: "Local-first notes with NDL v0 and LM Studio."),
            NoteBlock(kind: .bullet, text: "Encrypted vault at rest (stub in Phase 1)"),
            NoteBlock(kind: .bullet, text: "Related-note AI via LM Studio"),
            NoteBlock(kind: .quote, text: "Your corpus stays on this Mac by default.")
        ]
    )
}
