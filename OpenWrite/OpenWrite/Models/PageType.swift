import Foundation

/// Canonical page kinds — Anytype-style object types (local-only, extensible registry).
enum PageType: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case note
    case task
    case reference
    case journal
    case project
    case book
    case document
    case wikiSite = "wiki_site"
    case collection

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .note: return "Note"
        case .task: return "Task"
        case .reference: return "Reference"
        case .journal: return "Journal"
        case .project: return "Project"
        case .book: return "Book"
        case .document: return "Document"
        case .wikiSite: return "Wiki Site"
        case .collection: return "Collection"
        }
    }

    var accentColorName: String {
        switch self {
        case .note: return "blue"
        case .task: return "orange"
        case .reference: return "purple"
        case .journal: return "green"
        case .project: return "indigo"
        case .book: return "brown"
        case .document: return "teal"
        case .wikiSite: return "cyan"
        case .collection: return "gray"
        }
    }

    /// Object types shown in the quick type picker (excludes structure-first presets).
    static var quickPickTypes: [PageType] {
        [.note, .task, .reference, .journal, .project]
    }

    /// Types created primarily via structure templates.
    static var structurePageTypes: [PageType] {
        [.book, .document, .wikiSite, .collection]
    }
}

// MARK: - Extensible registry

/// Registry of built-in and future custom page types (Codable for vault bundles).
struct PageTypeRegistry: Codable, Hashable, Sendable {
    var builtIn: [PageType]
    var customTypeIDs: [String]

    static let `default` = PageTypeRegistry(
        builtIn: PageType.allCases,
        customTypeIDs: []
    )

    var allSelectable: [PageType] {
        builtIn
    }

    var quickPickSelectable: [PageType] {
        builtIn.filter { PageType.quickPickTypes.contains($0) }
    }

    func displayName(for typeID: String) -> String {
        if let builtIn = PageType(rawValue: typeID) {
            return builtIn.displayName
        }
        return typeID.capitalized
    }
}
