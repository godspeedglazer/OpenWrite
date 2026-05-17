import Foundation

/// Canonical page kinds — Anytype-style object types (local-only, extensible registry).
enum PageType: String, Codable, CaseIterable, Identifiable, Hashable, Sendable {
    case note
    case task
    case reference
    case journal
    case project

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .note: return "Note"
        case .task: return "Task"
        case .reference: return "Reference"
        case .journal: return "Journal"
        case .project: return "Project"
        }
    }

    var systemImage: String {
        switch self {
        case .note: return "doc.text"
        case .task: return "checkmark.circle"
        case .reference: return "link"
        case .journal: return "book.closed"
        case .project: return "folder"
        }
    }

    var accentColorName: String {
        switch self {
        case .note: return "blue"
        case .task: return "orange"
        case .reference: return "purple"
        case .journal: return "green"
        case .project: return "indigo"
        }
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

    func displayName(for typeID: String) -> String {
        if let builtIn = PageType(rawValue: typeID) {
            return builtIn.displayName
        }
        return typeID.capitalized
    }
}
