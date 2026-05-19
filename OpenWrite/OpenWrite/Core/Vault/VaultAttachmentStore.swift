import AppKit
import Foundation
import ImageIO
import UniformTypeIdentifiers
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

    private static let imageFileExtensions: Set<String> = [
        "png", "jpg", "jpeg", "gif", "heic", "tiff", "tif", "bmp", "webp"
    ]

    /// True when the general pasteboard has a raster image or an image file URL.
    static var pasteboardHasIngestibleImage: Bool {
        imageFromPasteboard() != nil || imageFileURLFromPasteboard() != nil
    }

    static func imageFileURLFromPasteboard() -> URL? {
        let pasteboard = NSPasteboard.general
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = pasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL] {
            for url in urls where isImageFileURL(url) {
                return url
            }
        }
        if let string = pasteboard.string(forType: .fileURL),
           let url = URL(string: string),
           isImageFileURL(url) {
            return url
        }
        return nil
    }

    static func imageFromPasteboard() -> NSImage? {
        if let url = imageFileURLFromPasteboard(), let image = NSImage(contentsOf: url) {
            return image
        }

        let pasteboard = NSPasteboard.general
        if let images = pasteboard.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let first = images.first {
            return first
        }

        for type in pasteboardImageTypes {
            guard let data = pasteboard.data(forType: type), !data.isEmpty else { continue }
            if let image = decodeRasterData(data) {
                return image
            }
        }
        return nil
    }

    private static var pasteboardImageTypes: [NSPasteboard.PasteboardType] {
        [
            .png,
            .tiff,
            NSPasteboard.PasteboardType(UTType.jpeg.identifier),
            NSPasteboard.PasteboardType(UTType.heic.identifier),
            NSPasteboard.PasteboardType(UTType.gif.identifier)
        ]
    }

    private static func decodeRasterData(_ data: Data) -> NSImage? {
        if let image = NSImage(data: data) {
            return image
        }
        guard let source = CGImageSourceCreateWithData(data as CFData, nil),
              let cgImage = CGImageSourceCreateImageAtIndex(source, 0, nil) else {
            return nil
        }
        return NSImage(
            cgImage: cgImage,
            size: NSSize(width: cgImage.width, height: cgImage.height)
        )
    }

    static func placeholderBlock(alt: String = "Pasting image…") -> NoteBlock {
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
        if let url = imageFileURLFromPasteboard() {
            return ingestImageFile(at: url, alt: alt, vaultRoot: vaultRoot)
        }
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

    static func finalizeImage(
        at url: URL,
        alt: String? = nil,
        vaultRoot: URL? = VaultLocationPreferences.resolvedVaultRootURL()
    ) async -> NoteBlock? {
        await Task.detached(priority: .userInitiated) {
            ingestImageFile(at: url, alt: alt, vaultRoot: vaultRoot)
        }.value
    }

    static func ingestImageFile(
        at url: URL,
        alt: String? = nil,
        vaultRoot: URL? = VaultLocationPreferences.resolvedVaultRootURL()
    ) -> NoteBlock? {
        guard let image = NSImage(contentsOf: url) else { return nil }
        let label = alt ?? url.deletingPathExtension().lastPathComponent
        do {
            let saved = try VaultAttachmentStore.saveImage(from: image, vaultRoot: vaultRoot)
            return NoteBlock.imageBlock(alt: label, assetId: saved.assetId, relativePath: saved.relativePath)
        } catch {
            return nil
        }
    }

    static func presentImagePicker(
        onPicked: @escaping (URL?) -> Void
    ) {
        let panel = NSOpenPanel()
        panel.title = "Insert image"
        panel.message = "Choose an image to add to this note"
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        if #available(macOS 11.0, *) {
            panel.allowedContentTypes = [.image]
        } else {
            panel.allowedFileTypes = ["png", "jpg", "jpeg", "gif", "heic", "tiff", "bmp", "webp"]
        }
        panel.begin { response in
            onPicked(response == .OK ? panel.url : nil)
        }
    }

    static func canAcceptDrag(_ info: NSDraggingInfo) -> Bool {
        if imageFileURL(from: info) != nil { return true }
        return imageFromPasteboard(draggingInfo: info) != nil
    }

    static func imageFileURL(from info: NSDraggingInfo) -> URL? {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        if let urls = info.draggingPasteboard.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
           let first = urls.first,
           isImageFileURL(first) {
            return first
        }
        return nil
    }

    private static func imageFromPasteboard(draggingInfo: NSDraggingInfo) -> NSImage? {
        let pb = draggingInfo.draggingPasteboard
        if let images = pb.readObjects(forClasses: [NSImage.self], options: nil) as? [NSImage],
           let first = images.first {
            return first
        }
        if let data = pb.data(forType: .tiff), let image = NSImage(data: data) {
            return image
        }
        if let data = pb.data(forType: .png), let image = NSImage(data: data) {
            return image
        }
        return nil
    }

    private static func isImageFileURL(_ url: URL) -> Bool {
        let ext = url.pathExtension.lowercased()
        if imageFileExtensions.contains(ext) { return true }
        if let values = try? url.resourceValues(forKeys: [.contentTypeKey]),
           let type = values.contentType,
           type.conforms(to: .image) {
            return true
        }
        return false
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
