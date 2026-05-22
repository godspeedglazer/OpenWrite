import CryptoKit
import Foundation

/// One markdown file discovered under the vault root (Reor indexes `.md` only).
struct VaultMarkdownFile: Sendable, Hashable {
    let documentID: UUID
    let relativePath: String
    let fileURL: URL
    let title: String
    let modifiedAt: Date

    var sourceFilename: String {
        if relativePath.hasSuffix(".md") { return relativePath }
        return (relativePath as NSString).lastPathComponent
    }
}

enum VaultMarkdownCatalog {
    private static let importer = MarkdownImporter()

    /// Recursively lists `*.md` under `vaultRoot`, skipping hidden vendor folders.
    static func scan(vaultRoot: URL) -> [VaultMarkdownFile] {
        let root = vaultRoot.standardizedFileURL
        guard FileManager.default.fileExists(atPath: root.path) else { return [] }

        guard let enumerator = FileManager.default.enumerator(
            at: root,
            includingPropertiesForKeys: [.isRegularFileKey, .contentModificationDateKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var results: [VaultMarkdownFile] = []
        for case let url as URL in enumerator {
            if shouldSkip(url: url, vaultRoot: root) {
                if url.hasDirectoryPath {
                    enumerator.skipDescendants()
                }
                continue
            }
            guard url.pathExtension.lowercased() == "md" else { continue }
            let relative = relativePath(for: url, vaultRoot: root)
            let title = url.deletingPathExtension().lastPathComponent
            let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            results.append(
                VaultMarkdownFile(
                    documentID: stableDocumentID(relativePath: relative),
                    relativePath: relative,
                    fileURL: url,
                    title: title,
                    modifiedAt: modified
                )
            )
        }
        return results.sorted { $0.relativePath.localizedCaseInsensitiveCompare($1.relativePath) == .orderedAscending }
    }

    static func loadBlocks(from file: VaultMarkdownFile) throws -> [NoteBlock] {
        let markdown = try String(contentsOf: file.fileURL, encoding: .utf8)
        let normalized = ObsidianMarkdownNormalizer.normalize(markdown)
        return importer.importString(normalized)
    }

    static func stableDocumentID(relativePath: String) -> UUID {
        let normalized = relativePath.replacingOccurrences(of: "\\", with: "/")
        let seed = "openwrite.markdown:\(normalized.lowercased())"
        let digest = SHA256.hash(data: Data(seed.utf8))
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }

    private static func relativePath(for fileURL: URL, vaultRoot: URL) -> String {
        let rootPath = vaultRoot.path.hasSuffix("/") ? vaultRoot.path : vaultRoot.path + "/"
        var path = fileURL.path
        if path.hasPrefix(rootPath) {
            path.removeFirst(rootPath.count)
        }
        return path
    }

    private static func shouldSkip(url: URL, vaultRoot: URL) -> Bool {
        let components = url.standardizedFileURL.pathComponents
        let rootComponents = vaultRoot.standardizedFileURL.pathComponents
        guard components.count > rootComponents.count else { return false }
        let relativeComponents = Array(components.dropFirst(rootComponents.count))
        return relativeComponents.contains { VaultLocationPreferences.hiddenDirectoryNames.contains($0) }
    }
}
