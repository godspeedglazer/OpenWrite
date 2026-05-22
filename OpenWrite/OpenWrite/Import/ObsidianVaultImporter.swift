import Foundation

struct ObsidianImportResult: Sendable {
    let copiedCount: Int
    let skippedCount: Int
    let relativePaths: [String]
}

/// Copies an Obsidian vault folder into the OpenWrite notes root (markdown only).
enum ObsidianVaultImporter {
    private static let skipDirectoryNames: Set<String> = [
        ".obsidian", ".git", ".trash", "node_modules", ".openwrite"
    ]

    static func importFolder(from sourceRoot: URL, into notesRoot: URL) throws -> ObsidianImportResult {
        let source = sourceRoot.standardizedFileURL
        let destination = notesRoot.standardizedFileURL
        try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true)

        guard let enumerator = FileManager.default.enumerator(
            at: source,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else {
            throw ObsidianImportError.enumerationFailed
        }

        var copied = 0
        var skipped = 0
        var paths: [String] = []

        for case let url as URL in enumerator {
            if shouldSkip(url: url, sourceRoot: source) {
                if url.hasDirectoryPath { enumerator.skipDescendants() }
                continue
            }
            guard url.pathExtension.lowercased() == "md" else { continue }

            let relative = relativePath(for: url, root: source)
            let target = destination.appendingPathComponent(relative)
            try FileManager.default.createDirectory(
                at: target.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )

            if FileManager.default.fileExists(atPath: target.path) {
                skipped += 1
                continue
            }

            let raw = try String(contentsOf: url, encoding: .utf8)
            let normalized = ObsidianMarkdownNormalizer.normalize(raw)
            try normalized.write(to: target, atomically: true, encoding: .utf8)
            copied += 1
            paths.append(relative)
        }

        return ObsidianImportResult(copiedCount: copied, skippedCount: skipped, relativePaths: paths)
    }

    private static func shouldSkip(url: URL, sourceRoot: URL) -> Bool {
        let components = url.standardizedFileURL.path
            .replacingOccurrences(of: sourceRoot.path + "/", with: "")
            .split(separator: "/")
            .map(String.init)
        return components.contains { skipDirectoryNames.contains($0) }
    }

    private static func relativePath(for fileURL: URL, root: URL) -> String {
        let rootPath = root.path.hasSuffix("/") ? root.path : root.path + "/"
        var path = fileURL.path
        if path.hasPrefix(rootPath) {
            path = String(path.dropFirst(rootPath.count))
        }
        return path
    }
}

enum ObsidianImportError: Error, LocalizedError {
    case enumerationFailed
    case userCancelled

    var errorDescription: String? {
        switch self {
        case .enumerationFailed: return "Could not read the selected folder."
        case .userCancelled: return "Import cancelled."
        }
    }
}
