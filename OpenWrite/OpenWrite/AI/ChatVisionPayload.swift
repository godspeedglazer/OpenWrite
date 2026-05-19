import Foundation

/// OpenAI-compatible multimodal user messages for LM Studio (Gemma 4 and other vision chat models).
enum ChatVisionPayload {
    /// Builds the `content` field for a user message — plain string or `[{type,text|image_url}]`.
    static func userMessageContent(
        text: String,
        imageAttachments: [ChatAttachment]
    ) -> Any {
        let images = imageAttachments.filter { $0.kind == .image }
        guard !images.isEmpty else {
            return text
        }

        var parts: [[String: Any]] = []
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            parts.append(["type": "text", "text": trimmed])
        }

        for attachment in images {
            guard let part = imageURLPart(for: attachment) else { continue }
            parts.append(part)
        }

        if parts.isEmpty {
            return text
        }
        if parts.count == 1, let only = parts.first, only["type"] as? String == "text" {
            return only["text"] as? String ?? text
        }
        return parts
    }

    static func estimatedContentTokens(_ content: Any) -> Int {
        if let text = content as? String {
            return AIInput.estimatedTokenCount(for: text)
        }
        guard let parts = content as? [[String: Any]] else { return 0 }
        var total = 0
        for part in parts {
            if let text = part["text"] as? String {
                total += AIInput.estimatedTokenCount(for: text)
            } else if let imageURL = part["image_url"] as? [String: Any],
                      let url = imageURL["url"] as? String,
                      url.hasPrefix("data:") {
                // Rough vision token budget from base64 payload size.
                total += max(256, url.count / 6)
            }
        }
        return total
    }

    private static func imageURLPart(for attachment: ChatAttachment) -> [String: Any]? {
        guard let data = try? Data(contentsOf: attachment.storedURL),
              !data.isEmpty,
              data.count <= AISafetyLimits.maxVisionImageBytes else {
            return nil
        }
        let mime = mimeType(for: attachment.storedURL)
        let encoded = data.base64EncodedString()
        return [
            "type": "image_url",
            "image_url": ["url": "data:\(mime);base64,\(encoded)"]
        ]
    }

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "jpg", "jpeg": return "image/jpeg"
        case "gif": return "image/gif"
        case "webp": return "image/webp"
        case "heic": return "image/heic"
        case "tif", "tiff": return "image/tiff"
        default: return "image/png"
        }
    }
}
