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
    /// Emoji or unicode glyph shown on the page banner (empty → type default).
    var pageIcon: String
    /// Optional gradient cover on the page header strip.
    var coverStyle: CoverStyle?
    /// Vault-relative path to a custom cover image (e.g. `.openwrite/covers/{id}.png`).
    var coverImagePath: String?
    /// Draggable page-icon offset on the cover strip (points, relative to default anchor).
    var pageIconOffsetX: CGFloat
    var pageIconOffsetY: CGFloat

    init(
        id: UUID = UUID(),
        title: String,
        pageType: PageType = .note,
        properties: PageProperties? = nil,
        rootBlocks: [NoteBlock] = [],
        createdAt: Date = .now,
        updatedAt: Date = .now,
        metadata: [String: String] = [:],
        pageIcon: String = "",
        coverStyle: CoverStyle? = nil,
        coverImagePath: String? = nil,
        pageIconOffsetX: CGFloat = 0,
        pageIconOffsetY: CGFloat = 0
    ) {
        self.id = id
        self.title = title
        self.pageType = pageType
        self.properties = properties ?? PageProperties.defaults(for: pageType, title: title)
        self.rootBlocks = rootBlocks
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.metadata = metadata
        self.pageIcon = pageIcon
        self.coverStyle = coverStyle
        self.coverImagePath = coverImagePath
        self.pageIconOffsetX = pageIconOffsetX
        self.pageIconOffsetY = pageIconOffsetY
    }

    /// Resolved display title — property title wins when set.
    var displayTitle: String {
        let propTitle = properties.string(for: .title).trimmingCharacters(in: .whitespacesAndNewlines)
        if !propTitle.isEmpty { return propTitle }
        return title
    }

    /// Banner emoji — explicit `pageIcon` or a type-default glyph.
    var resolvedPageIcon: String {
        let trimmed = pageIcon.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return pageType.defaultPageIcon
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

    /// Stable id for previews, Past Writes, and graph fixtures.
    static let welcomeDocumentID = UUID(uuidString: "E1C00001-7B2A-4E8F-9D01-000000000001")!

    static let welcomeSample: VaultDocument = {
        var doc = VaultDocument(
            id: welcomeDocumentID,
            title: "Welcome to OpenWrite",
            pageType: .note,
            properties: PageProperties.defaults(for: .note, title: "Welcome to OpenWrite"),
            rootBlocks: welcomeRootBlocks,
            metadata: [MetadataKey.prefersBlockEditor: "true"],
            pageIcon: "openwrite-logo",
            coverStyle: .anytypeCalm
        )
        doc.assignVault(OpenWriteVault.primaryID)
        return doc
    }()

    /// Welcome callouts use NDL variants mapped to `ThemePalette` semantic colors at render time
    /// (tip → success, note → accent, warning → warning).
    private static let welcomeRootBlocks: [NoteBlock] = [
        NoteBlock(
            kind: .callout,
            text: "This is your Space — a private graph of notes on this Mac. Everything below is yours to edit, link, and search.",
            attributes: ["callout": "tip"]
        ),
        NoteBlock(kind: .heading2, text: "Layout"),
        NoteBlock(
            kind: .paragraph,
            text: "OpenWrite keeps writing local-first: typed pages, NDL blocks, properties on every page, and optional on-device AI when you are ready."
        ),
        NoteBlock(
            kind: .bullet,
            text: "Sidebar — pages, databases, and the Graph object"
        ),
        NoteBlock(
            kind: .bullet,
            text: "Center column — block editor (this page) or graph canvas"
        ),
        NoteBlock(
            kind: .bullet,
            text: "Right strip — chat, related notes, and refine tools"
        ),
        NoteBlock(kind: .heading3, text: "Get started"),
        NoteBlock.todoBlock(text: "Click each checkbox below to mark progress", checked: false),
        NoteBlock.todoBlock(text: "Use + Block under the toolbar to add paragraphs, headings, checklists, or images"),
        NoteBlock.todoBlock(text: "Create a page with + in the sidebar"),
        NoteBlock.todoBlock(text: "Open Properties on the title row and set Status or Tags"),
        NoteBlock.todoBlock(text: "Type [[Another page]] or add a wikilink block to connect notes"),
        NoteBlock.todoBlock(text: "Open Graph under Objects to see how pages connect"),
        NoteBlock.todoBlock(text: "Copy an image and press ⌘V in the note (or drag a file onto the page)"),
        NoteBlock.todoBlock(text: "Ask a question in the AI chat strip with a note open"),
        NoteBlock(kind: .divider, text: ""),
        NoteBlock(kind: .heading3, text: "Explore"),
        NoteBlock(kind: .wikilink, text: "My first linked note"),
        NoteBlock(kind: .wikilink, text: "Research thread"),
        NoteBlock(
            kind: .paragraph,
            text: "Wikilinks name a page title. If no page exists yet, OpenWrite still indexes the title for search and future graph edges — create a page with the same title to connect them."
        ),
        NoteBlock(
            kind: .code,
            text: "wikilink My first linked note\nwikilink Research thread\n- [ ] NDL todos round-trip in plain text too",
            attributes: ["language": "ndl"]
        ),
        NoteBlock(
            kind: .callout,
            text: "Properties live above the body — use the Properties chip on the title row. Status and tags show as metadata chips.",
            attributes: ["callout": "note"]
        ),
        NoteBlock(
            kind: .callout,
            text: "Images: copy from any app (Finder, browser, screenshot) and press ⌘V in the note, or drag a file onto the page. Assets stay in your vault folder.",
            attributes: ["callout": "warning"]
        ),
        NoteBlock(kind: .heading3, text: "Documentation"),
        NoteBlock(
            kind: .bullet,
            text: "Project overview — docs/ProjectAtlas.md in the OpenWrite repository"
        ),
        NoteBlock(
            kind: .bullet,
            text: "Data model — docs/Architecture/DataModel.md (blocks, properties, NDL)"
        ),
        NoteBlock(
            kind: .bullet,
            text: "Lab runbook — build and run from OpenWrite/OpenWrite in Xcode"
        ),
        NoteBlock(kind: .quote, text: "Your corpus stays on this Mac by default — no account required.")
    ]

    static func fromTemplate(_ template: TypeTemplate) -> VaultDocument {
        VaultDocument(
            title: template.suggestedTitle,
            pageType: template.pageType,
            properties: template.properties,
            rootBlocks: template.rootBlocks
        )
    }

    /// NDL v0 body source for the plain editor (one serialized line per block).
    var plainText: String {
        let body = rootBlocks.filter { $0.kind != .property }
        return body.map { NDLSerializer.serializeBlock($0) }.joined(separator: "\n")
    }

    mutating func applyPlainText(_ text: String) {
        let propertyBlocks = rootBlocks.filter { $0.kind == .property }
        let body = NDLParser.parse(text)
        rootBlocks = propertyBlocks + body
        touchUpdatedAt()
    }

    // MARK: - Codable (backward-compatible)

    enum CodingKeys: String, CodingKey {
        case id, title, pageType, properties, rootBlocks, createdAt, updatedAt, metadata
        case pageIcon, coverStyle, coverImagePath, pageIconOffsetX, pageIconOffsetY
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
        pageIcon = try c.decodeIfPresent(String.self, forKey: .pageIcon) ?? ""
        coverStyle = try c.decodeIfPresent(CoverStyle.self, forKey: .coverStyle)
        coverImagePath = try c.decodeIfPresent(String.self, forKey: .coverImagePath)
        pageIconOffsetX = CGFloat(try c.decodeIfPresent(Double.self, forKey: .pageIconOffsetX) ?? 0)
        pageIconOffsetY = CGFloat(try c.decodeIfPresent(Double.self, forKey: .pageIconOffsetY) ?? 0)
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(title, forKey: .title)
        try c.encode(pageType, forKey: .pageType)
        try c.encode(properties, forKey: .properties)
        try c.encode(rootBlocks, forKey: .rootBlocks)
        try c.encode(createdAt, forKey: .createdAt)
        try c.encode(updatedAt, forKey: .updatedAt)
        try c.encode(metadata, forKey: .metadata)
        try c.encode(pageIcon, forKey: .pageIcon)
        try c.encodeIfPresent(coverStyle, forKey: .coverStyle)
        try c.encodeIfPresent(coverImagePath, forKey: .coverImagePath)
        try c.encode(Double(pageIconOffsetX), forKey: .pageIconOffsetX)
        try c.encode(Double(pageIconOffsetY), forKey: .pageIconOffsetY)
    }
}

// MARK: - Metadata

extension VaultDocument {
    enum MetadataKey {
        static let prefersBlockEditor = "prefersBlockEditor"
        /// When true, the page header hides the cover gradient strip (icon + title remain).
        static let coverStripCollapsed = "coverStripCollapsed"
    }

    var prefersBlockEditor: Bool {
        metadata[MetadataKey.prefersBlockEditor] == "true"
    }

    var isCoverStripCollapsed: Bool {
        metadata[MetadataKey.coverStripCollapsed] == "true"
    }

    mutating func setCoverStripCollapsed(_ collapsed: Bool) {
        if collapsed {
            metadata[MetadataKey.coverStripCollapsed] = "true"
        } else {
            metadata.removeValue(forKey: MetadataKey.coverStripCollapsed)
        }
    }
}

// MARK: - Page icon defaults

extension PageType {
    var defaultPageIcon: String {
        unicodeCharacter
    }
}
