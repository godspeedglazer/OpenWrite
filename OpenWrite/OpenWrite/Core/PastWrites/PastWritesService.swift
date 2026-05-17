import Foundation
import Combine

/// Optional “Past Writes” module: writing-session timeline from vault edits (+ optional REM import).
protocol PastWritesService: AnyObject {
    func recentContexts(since: Date) -> [WritingContextEntry]
    func snapshotSession(noteId: UUID) -> SessionSnapshot?
    func recordEdit(noteID: UUID, noteTitle: String, plainText: String)
}

enum PastWritesSessionPolicy {
    /// Merge edits on the same note within this idle gap into one session.
    static let idleMergeInterval: TimeInterval = 30 * 60
    static let excerptMaxCharacters = 240
}

@MainActor
final class InMemoryPastWritesService: ObservableObject, PastWritesService {
    @Published private(set) var sessions: [SessionSnapshot] = []

    private var openSessionByNote: [UUID: SessionSnapshot] = [:]
    private let remImport: REMImportAdapter

    init(remImport: REMImportAdapter = REMImportAdapter()) {
        self.remImport = remImport
        mergeImportedContextsIfAvailable()
    }

    func recentContexts(since: Date) -> [WritingContextEntry] {
        sessions
            .filter { $0.endedAt >= since }
            .sorted { $0.endedAt > $1.endedAt }
            .map(WritingContextEntry.init(from:))
    }

    func snapshotSession(noteId: UUID) -> SessionSnapshot? {
        if let open = openSessionByNote[noteId] { return open }
        return sessions.first { $0.noteID == noteId }
    }

    func recordEdit(noteID: UUID, noteTitle: String, plainText: String) {
        let now = Date()
        let excerpt = Self.excerpt(from: plainText)
        if var open = openSessionByNote[noteID],
           now.timeIntervalSince(open.endedAt) <= PastWritesSessionPolicy.idleMergeInterval {
            open.endedAt = now
            open.editCount += 1
            open.excerpt = excerpt
            open.noteTitle = noteTitle
            openSessionByNote[noteID] = open
            replaceStored(open)
            return
        }

        if openSessionByNote[noteID] != nil {
            finalizeOpenSession(noteID: noteID)
        }

        let session = SessionSnapshot(
            noteID: noteID,
            noteTitle: noteTitle,
            startedAt: now,
            endedAt: now,
            editCount: 1,
            excerpt: excerpt,
            source: .vaultEdits
        )
        openSessionByNote[noteID] = session
        sessions.insert(session, at: 0)
    }

    private func finalizeOpenSession(noteID: UUID) {
        guard let open = openSessionByNote.removeValue(forKey: noteID) else { return }
        replaceStored(open)
    }

    private func replaceStored(_ session: SessionSnapshot) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        }
    }

    private func mergeImportedContextsIfAvailable() {
        let imported = remImport.importWritingContextsIfPresent()
        guard !imported.isEmpty else { return }
        let existingIDs = Set(sessions.map(\.id))
        let novel = imported.filter { !existingIDs.contains($0.id) }
        sessions.append(contentsOf: novel)
        sessions.sort { $0.endedAt > $1.endedAt }
    }

    private static func excerpt(from plainText: String) -> String {
        let collapsed = plainText
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
        let maxLen = PastWritesSessionPolicy.excerptMaxCharacters
        guard collapsed.count > maxLen else { return collapsed }
        return String(collapsed.prefix(maxLen - 1)) + "…"
    }
}

extension InMemoryPastWritesService {
    static let preview: InMemoryPastWritesService = {
        let service = InMemoryPastWritesService()
        let noteID = VaultDocument.welcomeSample.id
        service.recordEdit(
            noteID: noteID,
            noteTitle: "Welcome to OpenWrite",
            plainText: "Drafting the welcome note."
        )
        return service
    }()
}
