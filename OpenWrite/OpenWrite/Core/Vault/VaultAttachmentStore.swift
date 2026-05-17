import AppKit
import Foundation
/// On-disk image attachments for pasted and embedded blocks.
/// Default fallback: `~/Library/Application Support/openwrite/attachments/{assetId}.png`
/// Vault-local: `{vaultRoot}/.openwrite/assets/{assetId}.{png|jpg}`
enum VaultAttachmentStore {
    static let appSubdirectory = "openwrite"
    static let attachmentsFolderName = "attachments"
    static let vaultAssetsFolderName = ".openwrite/assets"
    static let maxImageBytes = 12 * 1024 * 1024

    static var attachmentsDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent(appSubdirectory, isDirectory: true)
            .appendingPathComponent(attachmentsFolderName, isDirectory: true)
    }

    static func vaultAssetsDirectory(vaultRoot: URL) -> URL {
        vaultRoot
            .appendingPathComponent(".openwrite", isDirectory: true)
            .appendingPathComponent("assets", isDirectory: true)
    }

    static func ensureAttachmentsDirectory() throws {
        try FileManager.default.createDirectory(
            at: attachmentsDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    static func ensureVaultAssetsDirectory(vaultRoot: URL) throws {
        try FileManager.default.createDirectory(
            at: vaultAssetsDirectory(vaultRoot: vaultRoot),
            withIntermediateDirectories: true
        )
    }

    static func fileURL(forAssetId assetId: String, vaultRoot: URL? = nil) -> URL {
        if let vaultRoot {
            let dir = vaultAssetsDirectory(vaultRoot: vaultRoot)
            if let existing = existingAssetFile(assetId: assetId, in: dir) {
                return existing
            }
            return dir.appendingPathComponent("\(assetId.lowercased()).png")
        }
        return attachmentsDirectoryURL.appendingPathComponent("\(assetId.lowercased()).png")
    }

    private static func existingAssetFile(assetId: String, in directory: URL) -> URL? {
        let base = assetId.lowercased()
        for ext in ["png", "jpg", "jpeg"] {
            let url = directory.appendingPathComponent("\(base).\(ext)")
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }

    struct SavedImage: Sendable {
        let assetId: UUID
        let relativePath: String
        let fileURL: URL
    }

    @discardableResult
    static func saveImage(from image: NSImage, vaultRoot: URL? = nil) throws -> SavedImage {
        let encoded = try encodeImage(image)
        guard encoded.data.count <= maxImageBytes else {
            throw AttachmentError.tooLarge
        }

        let assetId = UUID()
        let assetIdString = assetId.uuidString.lowercased()

        if let vaultRoot {
            try ensureVaultAssetsDirectory(vaultRoot: vaultRoot)
            let filename = "\(assetIdString).\(encoded.fileExtension)"
            let url = vaultAssetsDirectory(vaultRoot: vaultRoot).appendingPathComponent(filename)
            try encoded.data.write(to: url)
            let relative = "\(vaultAssetsFolderName)/\(filename)"
            return SavedImage(assetId: assetId, relativePath: relative, fileURL: url)
        }

        try ensureAttachmentsDirectory()
        let filename = "\(assetIdString).\(encoded.fileExtension)"
        let url = attachmentsDirectoryURL.appendingPathComponent(filename)
        try encoded.data.write(to: url)
        return SavedImage(assetId: assetId, relativePath: filename, fileURL: url)
    }

    @discardableResult
    static func savePNG(from image: NSImage) throws -> UUID {
        try saveImage(from: image, vaultRoot: nil).assetId
    }

    static func loadImage(assetId: String, vaultRoot: URL? = nil) -> NSImage? {
        let url = fileURL(forAssetId: assetId, vaultRoot: vaultRoot)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }

    static func resolveFileURL(for block: NoteBlock, vaultRoot: URL? = VaultLocationPreferences.resolvedVaultRootURL()) -> URL? {
        if let assetId = block.imageAssetId {
            let url = fileURL(forAssetId: assetId, vaultRoot: vaultRoot)
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
            let fallback = fileURL(forAssetId: assetId, vaultRoot: nil)
            return FileManager.default.fileExists(atPath: fallback.path) ? fallback : nil
        }
        if let path = block.imagePath {
            if path.hasPrefix("/") {
                let url = URL(fileURLWithPath: path)
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
            if let vaultRoot {
                let vaultRelative = vaultRoot.appendingPathComponent(path)
                if FileManager.default.fileExists(atPath: vaultRelative.path) {
                    return vaultRelative
                }
            }
            let url = attachmentsDirectoryURL.appendingPathComponent(path)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        return nil
    }

    private static func encodeImage(_ image: NSImage) throws -> (data: Data, fileExtension: String) {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff) else {
            throw AttachmentError.encodeFailed
        }
        if let png = rep.representation(using: .png, properties: [:]) {
            return (png, "png")
        }
        if let jpeg = rep.representation(using: .jpeg, properties: [.compressionFactor: 0.88]) {
            return (jpeg, "jpg")
        }
        throw AttachmentError.encodeFailed
    }

    enum AttachmentError: Error {
        case encodeFailed
        case tooLarge
    }
}

enum ImagePasteSupport {
    static let pendingAttributeKey = "pending"

    static func imageFromPasteboard() -> NSImage? {
        let pasteboard = NSPasteboard.general
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let first = images.first {
            return first
        }
        if let data = pasteboard.data(forType: .tiff), let image = NSImage(data: data) {
            return image
        }
        if let data = pasteboard.data(forType: .png), let image = NSImage(data: data) {
            return image
        }
        return nil
    }

    static func placeholderBlock(alt: String = "Image") -> NoteBlock {
        NoteBlock(
            kind: .image,
            text: alt,
            attributes: [ImagePasteSupport.pendingAttributeKey: "true"]
        )
    }

    static func ingestPastedImage(
        alt: String = "Image",
        vaultRoot: URL? = VaultLocationPreferences.resolvedVaultRootURL()
    ) -> NoteBlock? {
        guard let image = imageFromPasteboard() else { return nil }
        do {
            let saved = try VaultAttachmentStore.saveImage(from: image, vaultRoot: vaultRoot)
            return NoteBlock.imageBlock(alt: alt, assetId: saved.assetId, relativePath: saved.relativePath)
        } catch {
            return nil
        }
    }

    static func finalizePastedImage(
        alt: String = "Image",
        vaultRoot: URL? = VaultLocationPreferences.resolvedVaultRootURL()
    ) async -> NoteBlock? {
        await Task.detached(priority: .userInitiated) {
            ingestPastedImage(alt: alt, vaultRoot: vaultRoot)
        }.value
    }

    static func copyImageToPasteboard(for block: NoteBlock, vaultRoot: URL? = VaultLocationPreferences.resolvedVaultRootURL()) -> Bool {
        guard let url = VaultAttachmentStore.resolveFileURL(for: block, vaultRoot: vaultRoot),
              let image = NSImage(contentsOf: url) else {
            return false
        }
        NSPasteboard.general.clearContents()
        return NSPasteboard.general.writeObjects([image])
    }
}
