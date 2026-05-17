import AppKit
import Foundation

/// On-disk image attachments for pasted and embedded blocks.
/// `~/Library/Application Support/openwrite/attachments/{assetId}.png`
enum VaultAttachmentStore {
    static let appSubdirectory = "openwrite"
    static let attachmentsFolderName = "attachments"

    static var attachmentsDirectoryURL: URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent(appSubdirectory, isDirectory: true)
            .appendingPathComponent(attachmentsFolderName, isDirectory: true)
    }

    static func ensureAttachmentsDirectory() throws {
        try FileManager.default.createDirectory(
            at: attachmentsDirectoryURL,
            withIntermediateDirectories: true
        )
    }

    static func fileURL(forAssetId assetId: String) -> URL {
        attachmentsDirectoryURL.appendingPathComponent("\(assetId.lowercased()).png")
    }

    @discardableResult
    static func savePNG(from image: NSImage) throws -> UUID {
        try ensureAttachmentsDirectory()
        let assetId = UUID()
        let url = fileURL(forAssetId: assetId.uuidString)
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else {
            throw AttachmentError.encodeFailed
        }
        try png.write(to: url)
        return assetId
    }

    static func loadImage(assetId: String) -> NSImage? {
        let url = fileURL(forAssetId: assetId)
        guard FileManager.default.fileExists(atPath: url.path) else { return nil }
        return NSImage(contentsOf: url)
    }

    static func resolveFileURL(for block: NoteBlock) -> URL? {
        if let assetId = block.imageAssetId {
            let url = fileURL(forAssetId: assetId)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        if let path = block.imagePath {
            if path.hasPrefix("/") {
                let url = URL(fileURLWithPath: path)
                return FileManager.default.fileExists(atPath: url.path) ? url : nil
            }
            let url = attachmentsDirectoryURL.appendingPathComponent(path)
            return FileManager.default.fileExists(atPath: url.path) ? url : nil
        }
        return nil
    }

    enum AttachmentError: Error {
        case encodeFailed
    }
}

enum ImagePasteSupport {
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

    static func ingestPastedImage(alt: String = "Image") -> NoteBlock? {
        guard let image = imageFromPasteboard() else { return nil }
        do {
            let assetId = try VaultAttachmentStore.savePNG(from: image)
            let filename = "\(assetId.uuidString.lowercased()).png"
            return NoteBlock.imageBlock(alt: alt, assetId: assetId, relativePath: filename)
        } catch {
            return nil
        }
    }
}
