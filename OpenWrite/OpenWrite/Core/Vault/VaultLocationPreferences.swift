import Foundation

/// Resolves the on-disk vault root used for Reor-style `.md` discovery and `.openwrite/assets/`.
enum VaultLocationPreferences {
    static let vaultRootPathKey = "openwrite.vaultRootPath"

    static let hiddenDirectoryNames: Set<String> = [".openwrite", ".git", ".obsidian", "node_modules"]

    static var defaultVaultRootURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("openwrite", isDirectory: true)
            .appendingPathComponent("vault", isDirectory: true)
    }

    /// User override when set; otherwise Application Support `openwrite/vault/`.
    static func resolvedVaultRootURL() -> URL {
        if let stored = UserDefaults.standard.string(forKey: vaultRootPathKey) {
            let url = URL(fileURLWithPath: stored, isDirectory: true)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return defaultVaultRootURL
    }

    static func setVaultRootURL(_ url: URL) {
        UserDefaults.standard.set(url.path, forKey: vaultRootPathKey)
    }

    /// Creates vault root and seeds a starter markdown note when empty.
    @discardableResult
    static func ensureDefaultVaultLayout() throws -> URL {
        let root = resolvedVaultRootURL()
        try FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
        try VaultAttachmentStore.ensureVaultAssetsDirectory(vaultRoot: root)
        try seedWelcomeMarkdownIfNeeded(at: root)
        return root
    }

    private static func seedWelcomeMarkdownIfNeeded(at root: URL) throws {
        let welcome = root.appendingPathComponent("Welcome.md")
        guard !FileManager.default.fileExists(atPath: welcome.path) else { return }
        let body = """
        # Welcome to OpenWrite

        This note lives on disk as **Welcome.md** in your vault folder. With **Search notes** enabled, chat and refine can retrieve it by filename, Reor-style.

        - Add more `.md` files anywhere under the vault (except `.openwrite/`).
        - Paste images in the block editor — they are stored under `.openwrite/assets/`.
        """
        try body.write(to: welcome, atomically: true, encoding: .utf8)
    }
}
