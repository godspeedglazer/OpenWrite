import Foundation

/// A bounded slice of writing activity on one note (vault edit history or imported REM context).
struct SessionSnapshot: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var noteID: UUID
    var noteTitle: String
    var startedAt: Date
    var endedAt: Date
    var editCount: Int
    var excerpt: String
    var source: WritingContextSource

    init(
        id: UUID = UUID(),
        noteID: UUID,
        noteTitle: String,
        startedAt: Date,
        endedAt: Date = .now,
        editCount: Int = 1,
        excerpt: String = "",
        source: WritingContextSource = .vaultEdits
    ) {
        self.id = id
        self.noteID = noteID
        self.noteTitle = noteTitle
        self.startedAt = startedAt
        self.endedAt = endedAt
        self.editCount = editCount
        self.excerpt = excerpt
        self.source = source
    }
}

/// Lightweight row for timeline / RAG context (screen-memory analogue without OCR in v1).
struct WritingContextEntry: Identifiable, Hashable, Sendable {
    var id: UUID
    var noteID: UUID
    var noteTitle: String
    var intervalStart: Date
    var intervalEnd: Date
    var summary: String
    var source: WritingContextSource

    init(from snapshot: SessionSnapshot) {
        id = snapshot.id
        noteID = snapshot.noteID
        noteTitle = snapshot.noteTitle
        intervalStart = snapshot.startedAt
        intervalEnd = snapshot.endedAt
        summary = snapshot.excerpt
        source = snapshot.source
    }
}

enum WritingContextSource: String, Codable, Sendable {
    case vaultEdits
    case remImport
}

/// Single edit event while a session is open (in-memory v1).
struct EditEvent: Identifiable, Hashable, Sendable {
    var id: UUID
    var timestamp: Date
    var characterDelta: Int
    var excerptTail: String
}
