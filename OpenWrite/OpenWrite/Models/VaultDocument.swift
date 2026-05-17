import Foundation

/// A single note inside an OpenWrite vault.
struct VaultDocument: Identifiable, Codable, Hashable, Sendable {
    var id: UUID
    var title: String
    var pageType: PageType
    var properties: PageProperties
    var rootBlocks: [NoteBlock]
    var createdAt: Date
    var updatedAt: Date
    var metadata: [String: String]

    init(
        id: UUID = UUID(),
        title: String,
        pageType: PageType = .note,
        properties: PageProperties? = nil,
        rootBlocks: [NoteBlock] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        metadata: [String: String] = [:]
    ) {
        self.id = id
        self.title = title
        self.pageType = pageType
        self.properties = properties ?? PageProperties.defaults(for: pageType, title: title)
        self.rootBlocks = rootBlocks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
    }

    /// Resolved display title — property title wins when set.
    var displayTitle: String {
        let propTitle = properties.string(for: .title).trimmingCharacters(in: .whitespacesAndNewlines)
        if !propTitle.isEmpty { return propTitle }
        return title
    }

    mutating func touchUpdatedAt() {
        updatedAt = .now
    }

    mutating func applyTemplate(_ template: TypeTemplate, preserveTitle: Bool = false) {
        pageType = template.pageType
        if !preserveTitle {
            title = template.suggestedTitle
        }
        properties = template.properties
        if properties.string(for: .title).isEmpty {
            properties.setText(title, for: .title)
        }
        rootBlocks = template.rootBlocks
        touchUpdatedAt()
    }

    static let welcomeSample = VaultDocument(
        title: "Welcome to OpenWrite",
        pageType: .note,
        properties: PageProperties.defaults(for: .note, title: "Welcome to OpenWrite"),
        rootBlocks: [
            NoteBlock(kind: .heading1, text: "Welcome to OpenWrite"),
            NoteBlock(kind: .paragraph, text: "Local-first notes with NDL v0 and typed pages."),
            NoteBlock(kind: .bullet, text: "Encrypted vault at rest (stub in Phase 1)"),
            NoteBlock(kind: .bullet, text: "Pick a page type — note, task, reference, journal, project"),
            NoteBlock(kind: .quote, text: "Your corpus stays on this Mac by default.")
        ]
    )

    static func fromTemplate(_ template: TypeTemplate) -> VaultDocument {
        VaultDocument(
            title: template.suggestedTitle,
            pageType: template.pageType,
            properties: template.properties,
            rootBlocks: template.rootBlocks
        )
    }

    /// Flattened block text for editing and Past Writes excerpts.
    var plainText: String {
        rootBlocks.map(\.text).joined(separator: "\n")
    }

    mutating func applyPlainText(_ text: String) {
        let lines = text.split(separator: "\n", omittingEmptySubsequences: false)
        rootBlocks = lines.map { line in
            NoteBlock(kind: .paragraph, text: String(line))
        }
        touchUpdatedAt()
    }

    // MARK: - Codable (backward-compatible)

    enum CodingKeys: String, CodingKey {
        case id, title, pageType, properties, rootBlocks, createdAt, updatedAt, metadata
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        title = try c.decode(String.self, forKey: .title)
        pageType = try c.decodeIfPresent(PageType.self, forKey: .pageType) ?? .note
        let decodedProps = try c.decodeIfPresent(PageProperties.self, forKey: .properties)
        properties = decodedProps ?? PageProperties.defaults(for: pageType, title: title)
        rootBlocks = try c.decodeIfPresent([NoteBlock].self, forKey: .rootBlocks) ?? []
        createdAt = try c.decodeIfPresent(Date.self, forKey: .createdAt) ?? .now
        updatedAt = try c.decodeIfPresent(Date.self, forKey: .updatedAt) ?? createdAt
        metadata = try c.decodeIfPresent([String: String].self, forKey: .metadata) ?? [:]
    }
}
