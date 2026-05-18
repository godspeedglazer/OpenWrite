import Foundation
import PDFKit
import UniformTypeIdentifiers

/// Chat file attachments stored under `{vaultRoot}/.openwrite/chat-attachments/`.
struct ChatAttachment: Identifiable, Hashable, Sendable {
    let id: UUID
    let displayName: String
    let storedURL: URL
    let excerpt: String
}

enum ChatAttachmentStore {
    static let folderName = "chat-attachments"
    static let maxFileBytes = 8 * 1024 * 1024
    static let maxExcerptChars = 2_400
    static let supportedExtensions: Set<String> = ["md", "txt", "pdf"]

    static var allowedContentTypes: [UTType] {
        [
            .plainText,
            .pdf,
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
        guard supportedExtensions.contains(ext) else {
            throw ChatAttachmentError.unsupportedType(ext)
        }

        let data = try Data(contentsOf: sourceURL, options: [.mappedIfSafe])
        guard data.count <= maxFileBytes else {
            throw ChatAttachmentError.tooLarge(maxFileBytes)
        }

        let displayName = sourceURL.lastPathComponent
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
            excerpt: excerpt
        )
    }

    static func retrievalHits(from attachments: [ChatAttachment]) -> [RetrievalHit] {
        attachments.map { attachment in
            RetrievalHit(
                attachmentID: attachment.id,
                filename: attachment.displayName,
                snippet: attachment.excerpt
            )
        }
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
            return "Unsupported file type “.\(ext)”. Use .md, .txt, or .pdf."
        case .tooLarge(let limit):
            return "File is too large (max \(limit / (1024 * 1024)) MB)."
        case .emptyContent:
            return "No readable text in that file."
        case .decodeFailed:
            return "Could not read that file."
        }
    }
}
