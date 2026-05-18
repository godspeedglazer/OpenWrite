import AppKit
import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Chat file attachments stored under `{vaultRoot}/.openwrite/chat-attachments/`.
struct ChatAttachment: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable, Sendable {
        case textDocument
        case image
    }

    let id: UUID
    let displayName: String
    let storedURL: URL
    let excerpt: String
    let kind: Kind
}

enum ChatAttachmentStore {
    static let folderName = "chat-attachments"
    static let maxFileBytes = 8 * 1024 * 1024
    static let maxImageBytes = 12 * 1024 * 1024
    static let maxExcerptChars = 2_400
    static let supportedExtensions: Set<String> = ["md", "txt", "pdf"]
    static let supportedImageExtensions: Set<String> = ["png", "jpg", "jpeg", "gif", "heic", "tiff", "tif", "bmp", "webp"]

    static var allowedContentTypes: [UTType] {
        [
            .plainText,
            .pdf,
            .image,
            UTType(filenameExtension: "md") ?? .plainText,
            UTType(filenameExtension: "txt") ?? .plainText
        ]
    }

    static func attachmentsDirectory(vaultRoot: URL) -> URL {
        vaultRoot
            .appendingPathComponent(".openwrite", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
    }

    static func fallbackAttachmentsDirectory() -> URL {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return base
            .appendingPathComponent("openwrite", isDirectory: true)
            .appendingPathComponent(folderName, isDirectory: true)
    }

    static func resolvedDirectory() throws -> URL {
        let vaultRoot = VaultLocationPreferences.resolvedVaultRootURL()
        let preferred = attachmentsDirectory(vaultRoot: vaultRoot)
        do {
            try FileManager.default.createDirectory(at: preferred, withIntermediateDirectories: true)
            return preferred
        } catch {
            let fallback = fallbackAttachmentsDirectory()
            try FileManager.default.createDirectory(at: fallback, withIntermediateDirectories: true)
            return fallback
        }
    }

    @MainActor
    static func importFile(from sourceURL: URL) throws -> ChatAttachment {
        let ext = sourceURL.pathExtension.lowercased()
        let isTextLike = supportedExtensions.contains(ext)
        let isImage = supportedImageExtensions.contains(ext)
        guard isTextLike || isImage else {
            throw ChatAttachmentError.unsupportedType(ext)
        }

        let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        let maxBytes = isImage ? maxImageBytes : maxFileBytes
        guard data.count <= maxBytes else { throw ChatAttachmentError.tooLarge(maxBytes) }

        let displayName = sourceURL.lastPathComponent
        if isImage {
            guard let image = NSImage(data: data) else {
                throw ChatAttachmentError.decodeFailed
            }
            return try importImage(image, displayName: displayName)
        }

        let text = try extractText(from: sourceURL, extension: ext, data: data)
        let excerpt = AIInput.sanitizeSnippet(text, maxChars: maxExcerptChars)
        guard !excerpt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ChatAttachmentError.emptyContent
        }

        let id = UUID()
        let directory = try resolvedDirectory()
        let destination = directory.appendingPathComponent("\(id.uuidString.lowercased()).\(ext)")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destination)

        return ChatAttachment(
            id: id,
            displayName: displayName,
            storedURL: destination,
            excerpt: excerpt,
            kind: .textDocument
        )
    }

    @MainActor
    static func importPastedImage(_ image: NSImage, suggestedName: String? = nil) throws -> ChatAttachment {
        let trimmed = suggestedName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let base = trimmed.isEmpty ? "Pasted image" : trimmed
        let displayName = "\(base).png"
        return try importImage(image, displayName: displayName)
    }

    static func retrievalHits(from attachments: [ChatAttachment]) -> [RetrievalHit] {
        attachments.map { attachment in
            RetrievalHit(
                attachmentID: attachment.id,
                filename: attachment.displayName,
                snippet: attachment.kind == .image
                    ? "Image attachment: \(attachment.displayName)"
                    : attachment.excerpt
            )
        }
    }

    private static func importImage(_ image: NSImage, displayName: String) throws -> ChatAttachment {
        guard let tiff = image.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let pngData = rep.representation(using: .png, properties: [:]) else {
            throw ChatAttachmentError.decodeFailed
        }
        guard pngData.count <= maxImageBytes else {
            throw ChatAttachmentError.tooLarge(maxImageBytes)
        }

        let id = UUID()
        let directory = try resolvedDirectory()
        let destination = directory.appendingPathComponent("\(id.uuidString.lowercased()).png")
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try pngData.write(to: destination)

        return ChatAttachment(
            id: id,
            displayName: displayName,
            storedURL: destination,
            excerpt: "Image attachment: \(displayName)",
            kind: .image
        )
    }

    private static func extractText(from url: URL, extension ext: String, data: Data) throws -> String {
        switch ext {
        case "md", "txt":
            guard let text = String(data: data, encoding: .utf8) else {
                throw ChatAttachmentError.decodeFailed
            }
            return text
        case "pdf":
            guard let document = PDFDocument(url: url) ?? PDFDocument(data: data) else {
                throw ChatAttachmentError.decodeFailed
            }
            let pages = (0 ..< document.pageCount).compactMap { document.page(at: $0)?.string }
            let joined = pages.joined(separator: "\n")
            guard !joined.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                throw ChatAttachmentError.emptyContent
            }
            return joined
        default:
            throw ChatAttachmentError.unsupportedType(ext)
        }
    }
}

enum ChatAttachmentError: LocalizedError {
    case unsupportedType(String)
    case tooLarge(Int)
    case emptyContent
    case decodeFailed

    var errorDescription: String? {
        switch self {
        case .unsupportedType(let ext):
            return "Unsupported file type “.\(ext)”. Use text, PDF, or common image files."
        case .tooLarge(let limit):
            return "File is too large (max \(limit / (1024 * 1024)) MB)."
        case .emptyContent:
            return "No readable text in that file."
        case .decodeFailed:
            return "Could not read that file."
        }
    }
}
