import Foundation

/// Anytype-inspired structure presets — local-only heading scaffolds and optional child pages.
enum StructureTemplate: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case book
    case document
    case wikiSite = "wiki_site"
    case collection

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .book: return "Book"
        case .document: return "Document"
        case .wikiSite: return "Wiki Site"
        case .collection: return "Collection"
        }
    }

    var systemImage: String {
        switch self {
        case .book: return "books.vertical"
        case .document: return "doc.richtext"
        case .wikiSite: return "globe"
        case .collection: return "folder"
        }
    }

    var summary: String {
        switch self {
        case .book:
            return "Long-form writing with chapter headings."
        case .document:
            return "Structured sections with H1–H3 outline."
        case .wikiSite:
            return "Home page plus linked site pages."
        case .collection:
            return "Folder-like grouping with item links."
        }
    }

    /// Canonical page type for this structure preset.
    var pageType: PageType {
        switch self {
        case .book: return .book
        case .document: return .document
        case .wikiSite: return .wikiSite
        case .collection: return .collection
        }
    }

    static func from(pageType: PageType) -> StructureTemplate? {
        switch pageType {
        case .book: return .book
        case .document: return .document
        case .wikiSite: return .wikiSite
        case .collection: return .collection
        default: return nil
        }
    }

    // MARK: - Outline

    /// A single heading in the structure scaffold (levels 1–3).
    struct OutlineHeading: Hashable, Sendable {
        let level: Int
        let title: String
        var placeholder: String?

        init(level: Int, title: String, placeholder: String? = nil) {
            self.level = min(3, max(1, level))
            self.title = title
            self.placeholder = placeholder
        }
    }

    /// Default H1/H2/H3 scaffold for the root page (titles may include `{title}` token).
    func headingOutline(rootTitle: String) -> [OutlineHeading] {
        let title = rootTitle
        switch self {
        case .book:
            return [
                OutlineHeading(level: 1, title: title, placeholder: "Synopsis and how to use this book."),
                OutlineHeading(level: 2, title: "Chapter 1", placeholder: "Opening chapter…"),
                OutlineHeading(level: 2, title: "Chapter 2", placeholder: "Continue the narrative…"),
                OutlineHeading(level: 2, title: "Chapter 3", placeholder: "Closing chapter…")
            ]
        case .document:
            return [
                OutlineHeading(level: 1, title: title, placeholder: "Executive summary or abstract."),
                OutlineHeading(level: 2, title: "Introduction"),
                OutlineHeading(level: 3, title: "Context", placeholder: "Background for the reader."),
                OutlineHeading(level: 2, title: "Body"),
                OutlineHeading(level: 3, title: "Section A", placeholder: "Main argument or content."),
                OutlineHeading(level: 3, title: "Section B", placeholder: "Supporting detail."),
                OutlineHeading(level: 2, title: "Conclusion", placeholder: "Wrap up and next steps.")
            ]
        case .wikiSite:
            return [
                OutlineHeading(level: 1, title: title, placeholder: "Welcome — what this site covers."),
                OutlineHeading(level: 2, title: "Site map"),
                OutlineHeading(level: 2, title: "Getting started", placeholder: "How to navigate the wiki.")
            ]
        case .collection:
            return [
                OutlineHeading(level: 1, title: title, placeholder: "Describe what belongs in this collection."),
                OutlineHeading(level: 2, title: "Items"),
                OutlineHeading(level: 2, title: "Notes", placeholder: "Grouping rules or conventions.")
            ]
        }
    }

    /// Child pages created alongside the root (wiki tree, collection items).
    func childPageSpecs(rootTitle: String) -> [ChildPageSpec] {
        switch self {
        case .book:
            return []
        case .document:
            return []
        case .wikiSite:
            let prefix = rootTitle == displayName ? "Site" : rootTitle
            return [
                ChildPageSpec(title: "\(prefix) — About", pageType: .note),
                ChildPageSpec(title: "\(prefix) — Guide", pageType: .note),
                ChildPageSpec(title: "\(prefix) — Reference", pageType: .reference)
            ]
        case .collection:
            return [
                ChildPageSpec(title: "Item 1", pageType: .note),
                ChildPageSpec(title: "Item 2", pageType: .note),
                ChildPageSpec(title: "Item 3", pageType: .note)
            ]
        }
    }

    struct ChildPageSpec: Hashable, Sendable {
        let title: String
        let pageType: PageType
        var outline: [OutlineHeading]?

        init(title: String, pageType: PageType, outline: [OutlineHeading]? = nil) {
            self.title = title
            self.pageType = pageType
            self.outline = outline
        }
    }

    // MARK: - Block generation

    func makeRootBlocks(title: String, childTitles: [String] = []) -> [NoteBlock] {
        var blocks = Self.blocks(from: headingOutline(rootTitle: title))

        switch self {
        case .wikiSite, .collection:
            let links = childTitles.isEmpty ? childPageSpecs(rootTitle: title).map(\.title) : childTitles
            for linkTitle in links {
                blocks.append(NoteBlock(kind: .wikilink, text: linkTitle))
            }
        case .book, .document:
            break
        }

        blocks.append(NoteBlock(kind: .divider, text: ""))
        blocks.append(NoteBlock(kind: .paragraph, text: ""))
        return blocks
    }

    static func blocks(from outline: [OutlineHeading]) -> [NoteBlock] {
        outline.flatMap { heading -> [NoteBlock] in
            let kind: NoteBlock.Kind = switch heading.level {
            case 1: .heading1
            case 2: .heading2
            default: .heading3
            }
            var result = [NoteBlock(kind: kind, text: heading.title)]
            if let placeholder = heading.placeholder, !placeholder.isEmpty {
                result.append(NoteBlock(kind: .paragraph, text: placeholder))
            }
            return result
        }
    }

    // MARK: - Metadata keys

    enum MetadataKey {
        static let structureTemplate = "structureTemplate"
        static let parentDocumentID = "parentDocumentID"
        static let childDocumentIDs = "childDocumentIDs"
    }
}
