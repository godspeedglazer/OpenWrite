import Foundation

/// Primary workbench sidebar destinations (major ride stub).
enum SidebarSection: String, CaseIterable, Identifiable, Sendable {
    case notes
    case graph
    case search
    case ai
    case publish

    var id: String { rawValue }

    var title: String {
        switch self {
        case .notes: return "Notes"
        case .graph: return "Graph"
        case .search: return "Search"
        case .ai: return "AI"
        case .publish: return "Publish"
        }
    }
}
