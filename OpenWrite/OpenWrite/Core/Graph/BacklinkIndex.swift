import Foundation

/// Wikilink and reference graph index (major ride stub).
struct BacklinkIndex: Sendable {
    private var incoming: [UUID: Set<UUID>] = [:]

    mutating func registerLink(from sourceDocumentID: UUID, to targetDocumentID: UUID) {
        incoming[targetDocumentID, default: []].insert(sourceDocumentID)
    }

    func backlinks(to documentID: UUID) -> [UUID] {
        Array(incoming[documentID] ?? []).sorted { $0.uuidString < $1.uuidString }
    }
}
