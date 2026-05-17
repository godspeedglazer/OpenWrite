import Foundation

/// Codable vault bundle payload for future `.openwrite` persistence.
struct VaultSnapshot: Codable, Sendable {
    var documents: [VaultDocument]
    var databases: [OWDatabase]
    var databaseEntries: [OWDatabaseEntry]
    var version: Int

    static let currentVersion = 1

    init(
        documents: [VaultDocument],
        databases: [OWDatabase],
        databaseEntries: [OWDatabaseEntry],
        version: Int = Self.currentVersion
    ) {
        self.documents = documents
        self.databases = databases
        self.databaseEntries = databaseEntries
        self.version = version
    }
}
