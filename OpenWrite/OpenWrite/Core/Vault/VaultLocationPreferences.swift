import Foundation

/// Resolves the on-disk notes folder for `.md` discovery and `.openwrite/assets/`.
enum VaultLocationPreferences {
    static let vaultRootPathKey = "openwrite.vaultRootPath"
    static let notesRootPathKey = "openwrite.notesRootPath"

    static let hiddenDirectoryNames: Set<String> = [".openwrite", ".git", ".obsidian", "node_modules"]

    static var defaultNotesRootURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("openwrite", isDirectory: true)
            .appendingPathComponent("notes", isDirectory: true)
    }

    /// Legacy path (`openwrite/vault/`) for upgrades from older builds.
    static var legacyVaultRootURL: URL {
        defaultNotesRootURL.deletingLastPathComponent().appendingPathComponent("vault", isDirectory: true)
    }

    static var defaultVaultRootURL: URL { defaultNotesRootURL }

    /// User override when set; otherwise Application Support `openwrite/notes/` (migrates legacy `vault/`).
    static func resolvedVaultRootURL() -> URL {
        if let stored = UserDefaults.standard.string(forKey: notesRootPathKey) {
            let url = URL(fileURLWithPath: stored, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        if let stored = UserDefaults.standard.string(forKey: vaultRootPathKey) {
            let url = URL(fileURLWithPath: stored, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        let notes = defaultNotesRootURL
        if FileManager.default.fileExists(atPath: notes.path) {
            return notes
        }
        let legacy = legacyVaultRootURL
        if FileManager.default.fileExists(atPath: legacy.path) {
            return legacy
        }
        return notes
    }

    static func setVaultRootURL(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: vaultRootPathKey)
    }

    /// Creates the notes folder and seeds a starter markdown page when empty.
    @discardableResult
    static func ensureDefaultVaultLayout() throws -> URL {
        let root = resolvedVaultRootURL()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try migrateLegacyVaultFolderIfNeeded(to: root)
        try VaultAttachmentStore.ensureVaultAssetsDirectory(vaultRoot: root)
        try VaultCoverStore.ensureCoversDirectory(vaultRoot: root)
        try seedWelcomeMarkdownIfNeeded(at: root)
        return root
    }

    /// Moves `openwrite/vault/` → `openwrite/notes/` when only the legacy folder exists.
    private static func migrateLegacyVaultFolderIfNeeded(to notesRoot: URL) throws {
        let legacy = legacyVaultRootURL
        guard legacy != notesRoot else { return }
        guard FileManager.default.fileExists(atPath: legacy.path) else { return }
        guard !FileManager.default.fileExists(atPath: notesRoot.path)
            || (try? FileManager.default.contentsOfDirectory(atPath: notesRoot.path))?.isEmpty == true else {
            return
        }
        try FileManager.default.createDirectory(at: notesRoot.deletingLastPathComponent(), withIntermediateDirectories: true)
        try FileManager.default.moveItem(at: legacy, to: notesRoot)
    }

    private static func seedWelcomeMarkdownIfNeeded(at root: URL) throws {
        let welcome = root.appendingPathComponent("Welcome.md")
        guard !FileManager.default.fileExists(atPath: welcome.path) else { return }
        let body = """
        # Welcome to OpenWrite

        This page lives on disk as **Welcome.md** in your notes folder. With **Search notes** enabled, chat and refine can retrieve it by filename.

        - Add more `.md` files anywhere under your notes folder (except `.openwrite/`).
        - Paste images in the block editor — they are stored under `.openwrite/assets/`.
        """
        try body.write(to: welcome, atomically: true, encoding: .utf8)
    }
}
