import Foundation

/// Center column mode — editor, graph, or a universal database table.
enum CenterWorkbenchTab: Identifiable, Equatable, Sendable {
    case editor
    case graph
    case database(OWDatabase)

    var id: String {
        switch self {
        case .editor: return "editor"
        case .graph: return "graph"
        case .database(let database): return "database-\(database.id.uuidString)"
        }
    }

    var title: String {
        switch self {
        case .editor: return "Editor"
        case .graph: return "Graph"
        case .database: return "Database"
        }
    }

    var isDatabase: Bool {
        if case .database = self { return true }
        return false
    }

    var databaseID: UUID? {
        if case .database(let database) = self { return database.id }
        return nil
    }
}
