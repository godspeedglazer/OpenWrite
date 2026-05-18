import AppKit
import Foundation
import UniformTypeIdentifiers

/// Page cover images stored under `{vaultRoot}/.openwrite/covers/`.
enum VaultCoverStore {
    static let coversFolderName = "covers"
    static let relativePrefix = ".openwrite/covers"
    static let maxImageBytes = 8 * 1024 * 1024

    static func vaultCoversDirectory(vaultRoot: URL) -> URL {
        vaultRoot
            .appendingPathComponent(".openwrite", isDirectory: true)
            .appendingPathComponent(coversFolderName, isDirectory: true)
    }

    static func ensureCoversDirectory(vaultRoot: URL) throws {
        try FileManager.default.createDirectory(
            at: vaultCoversDirectory(vaultRoot: vaultRoot),
            withIntermediateDirectories: true
        )
    }

    /// Relative path persisted on `VaultDocument.coverImagePath` (vault-root relative).
    static func relativePath(filename: String) -> String {
        "\(relativePrefix)/\(filename)"
    }

    static func resolveURL(relativePath: String, vaultRoot: URL) -> URL {
        if relativePath.hasPrefix(relativePrefix) {
            return vaultRoot.appendingPathComponent(relativePath)
        }
        return vaultRoot.appendingPathComponent(relativePath)
    }

    static func fileURL(documentID: UUID, vaultRoot: URL) -> URL? {
        let dir = vaultCoversDirectory(vaultRoot: vaultRoot)
        let base = documentID.uuidString.lowercased()
        for ext in ["webp", "png", "jpg", "jpeg"] {
            let url = dir.appendingPathComponent("\(base).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    /// Imports a user-selected image; returns vault-relative path for persistence.
    @discardableResult
    static func importCover(
        from sourceURL: URL,
        documentID: UUID,
        vaultRoot: URL
    ) throws -> String {
        let data = try Data(contentsOf: sourceURL)
        guard data.count <= maxImageBytes else {
            throw CoverError.tooLarge
        }

        let ext = sourceURL.pathExtension.lowercased()
        let normalizedExt: String
        switch ext {
        case "jpg", "jpeg": normalizedExt = "jpg"
        case "webp": normalizedExt = "webp"
        default: normalizedExt = "png"
        }

        try ensureCoversDirectory(vaultRoot: vaultRoot)
        removeExistingFiles(documentID: documentID, vaultRoot: vaultRoot)

        let filename = "\(documentID.uuidString.lowercased()).\(normalizedExt)"
        let dest = vaultCoversDirectory(vaultRoot: vaultRoot).appendingPathComponent(filename)
        try data.write(to: dest, options: .atomic)
        return relativePath(filename: filename)
    }

    static func removeCover(documentID: UUID, vaultRoot: URL) {
        removeExistingFiles(documentID: documentID, vaultRoot: vaultRoot)
    }

    private static func removeExistingFiles(documentID: UUID, vaultRoot: URL) {
        let dir = vaultCoversDirectory(vaultRoot: vaultRoot)
        let base = documentID.uuidString.lowercased()
        for ext in ["webp", "png", "jpg", "jpeg"] {
            let url = dir.appendingPathComponent("\(base).\(ext)")
            try? FileManager.default.removeItem(at: url)
        }
    }

    enum CoverError: LocalizedError {
        case tooLarge
        case importFailed

        var errorDescription: String? {
            switch self {
            case .tooLarge: return "Cover image must be under 8 MB."
            case .importFailed: return "Could not import the selected image."
            }
        }
    }

    static var openPanelAllowedTypes: [UTType] {
        [.png, .jpeg, .webP]
    }
}
