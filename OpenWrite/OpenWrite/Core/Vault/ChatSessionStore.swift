import Foundation

/// Persisted vault chat thread saved when the user taps Clear.
struct SavedChatThread: Codable, Sendable, Identifiable {
    let id: UUID
    let savedAt: Date
    let agentID: String
    let turns: [SavedChatTurn]
    /// Short heuristic summary for future RAG / recall without holding full history in memory.
    let contextSummary: String?
}

struct SavedChatTurn: Codable, Sendable {
    let role: String
    let text: String
    var attachmentNames: [String]
    var visionAttachments: [SavedVisionAttachment]

    init(
        role: String,
        text: String,
        attachmentNames: [String] = [],
        visionAttachments: [SavedVisionAttachment] = []
    ) {
        self.role = role
        self.text = text
        self.attachmentNames = attachmentNames
        self.visionAttachments = visionAttachments
    }

    private enum CodingKeys: String, CodingKey {
        case role
        case text
        case attachmentNames
        case visionAttachments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        role = try container.decode(String.self, forKey: .role)
        text = try container.decode(String.self, forKey: .text)
        attachmentNames = try container.decodeIfPresent([String].self, forKey: .attachmentNames) ?? []
        visionAttachments = try container.decodeIfPresent([SavedVisionAttachment].self, forKey: .visionAttachments) ?? []
    }
}

/// Image attachment snapshot for archived threads (absolute path under chat-attachments).
struct SavedVisionAttachment: Codable, Sendable, Hashable {
    let id: UUID
    let displayName: String
    let storedPath: String
}

/// In-memory message payload passed into `ChatSessionStore.archive`.
struct ChatSessionArchiveMessage: Sendable {
    let role: String
    let text: String
    let isError: Bool
    let attachmentNames: [String]
    let visionAttachments: [ChatAttachment]
}

enum ChatSessionStore {
    private static let directoryName = "chat_sessions"
    private static let maxArchivedThreads = 64

    static var sessionsDirectory: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("openwrite", isDirectory: true)
            .appendingPathComponent(directoryName, isDirectory: true)
    }

    /// Archives the current in-memory transcript and returns the saved record id.
    @discardableResult
    static func archive(messages: [ChatSessionArchiveMessage], agentID: String) throws -> UUID {
        let turns = messages.compactMap { message -> SavedChatTurn? in
            let trimmed = message.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty || !message.attachmentNames.isEmpty else { return nil }
            let savedVision = message.visionAttachments
                .filter { $0.kind == .image }
                .map {
                    SavedVisionAttachment(
                        id: $0.id,
                        displayName: $0.displayName,
                        storedPath: $0.storedURL.path
                    )
                }
            return SavedChatTurn(
                role: message.role,
                text: trimmed.isEmpty ? message.text : trimmed,
                attachmentNames: message.attachmentNames,
                visionAttachments: savedVision
            )
        }
        guard !turns.isEmpty else { return UUID() }

        let thread = SavedChatThread(
            id: UUID(),
            savedAt: .now,
            agentID: agentID,
            turns: turns,
            contextSummary: makeContextSummary(from: turns)
        )

        try FileManager.default.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
        let url = sessionsDirectory.appendingPathComponent("\(thread.id.uuidString).json")
        let data = try JSONEncoder().encode(thread)
        try data.write(to: url, options: .atomic)
        try pruneOldSessions()
        return thread.id
    }

    static func loadThread(id: UUID) -> SavedChatThread? {
        let url = sessionsDirectory.appendingPathComponent("\(id.uuidString).json")
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(SavedChatThread.self, from: data)
    }

    static func loadRecent(limit: Int = 20) -> [SavedChatThread] {
        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else { return [] }

        let sorted = urls
            .filter { $0.pathExtension == "json" }
            .sorted {
                let d0 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                let d1 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
                return d0 > d1
            }

        return sorted.prefix(limit).compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? JSONDecoder().decode(SavedChatThread.self, from: data)
        }
    }

    private static func pruneOldSessions() throws {
        let urls = try FileManager.default.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        )
        let jsonFiles = urls.filter { $0.pathExtension == "json" }
        guard jsonFiles.count > maxArchivedThreads else { return }

        let sorted = jsonFiles.sorted {
            let d0 = (try? $0.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            let d1 = (try? $1.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return d0 > d1
        }
        for url in sorted.dropFirst(maxArchivedThreads) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    static func makeContextSummary(from turns: [SavedChatTurn]) -> String? {
        let users = turns.filter { $0.role == "user" }.map(\.text)
        let assistants = turns.filter { $0.role == "assistant" }.map(\.text)
        guard !users.isEmpty else { return nil }

        let topic = String(users.joined(separator: " ").prefix(160))
        var parts: [String] = ["Chat topic: \(topic)"]
        if let last = assistants.last?.trimmingCharacters(in: .whitespacesAndNewlines), !last.isEmpty {
            let answer = String(last.prefix(200))
            parts.append("Last answer: \(answer)")
        }
        return parts.joined(separator: "\n")
    }
}
