import Foundation

/// Clean-room stub: optional import of writing-adjacent context from a local rem+ SQLite export.
///
/// rem+ (user-authored fork, MIT) stores screen-memory frames in `db.sqlite3` under its save directory.
/// OpenWrite does not embed rem+ or require screen capture for Past Writes v1; this adapter only
/// reads an existing database file when the operator points at it or when the default path exists.
struct REMImportAdapter: Sendable {
    /// Typical rem+ layout: `<saveDir>/db.sqlite3` (see rem+ `RemDatabase.databasePath()`).
    var exportDatabasePath: String?

    init(exportDatabasePath: String? = nil) {
        self.exportDatabasePath = exportDatabasePath
    }

    /// Resolves rem+ `db.sqlite3` if present (Application Support save dir, then legacy container).
    func resolvedExportPath() -> String? {
        if let exportDatabasePath, FileManager.default.fileExists(atPath: exportDatabasePath) {
            return exportDatabasePath
        }
        let home = FileManager.default.homeDirectoryForCurrentUser
        let candidates = [
            home.appendingPathComponent("Library/Application Support/rem/db.sqlite3"),
            home.appendingPathComponent(
                "Library/Containers/today.jason.rem/Data/Library/Application Support/db.sqlite3"
            )
        ]
        return candidates.map(\.path).first { FileManager.default.fileExists(atPath: $0) }
    }

    /// v1 stub: returns empty unless a DB file exists; future work can map `frames` / `frames_text` rows.
    func importWritingContextsIfPresent() -> [SessionSnapshot] {
        guard resolvedExportPath() != nil else { return [] }
        // Intentionally no SQLite dependency in OpenWrite v1 — placeholder marks import availability.
        return []
    }
}
