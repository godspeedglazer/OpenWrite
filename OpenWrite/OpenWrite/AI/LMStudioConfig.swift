import Foundation

/// User-configurable LM Studio (OpenAI-compatible) endpoint.
struct LMStudioConfig: Codable, Hashable, Sendable {
    var baseURL: URL
    var chatModel: String
    var embeddingModel: String
    var apiKey: String?
    var timeoutSeconds: TimeInterval
    var streamingEnabled: Bool

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:1234")!,
        chatModel: String = "local-model",
        embeddingModel: String = "",
        apiKey: String? = nil,
        timeoutSeconds: TimeInterval = 60,
        streamingEnabled: Bool = true
    ) {
        self.baseURL = baseURL
        self.chatModel = chatModel
        self.embeddingModel = embeddingModel
        self.apiKey = apiKey
        self.timeoutSeconds = timeoutSeconds
        self.streamingEnabled = streamingEnabled
    }

    static let `default` = LMStudioConfig()

    /// OpenAI-compatible `/v1` root.
    var apiV1BaseURL: URL {
        LMStudioURLPolicy.v1BaseURL(from: baseURL)
    }

    var chatCompletionsURL: URL {
        apiV1BaseURL.appending(path: "chat/completions")
    }

    var modelsURL: URL {
        apiV1BaseURL.appending(path: "models")
    }

    var embeddingsURL: URL {
        apiV1BaseURL.appending(path: "embeddings")
    }

    var resolvedEmbeddingModel: String {
        let trimmed = embeddingModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        return chatModel
    }
}

enum LMStudioURLPolicy {
    static func v1BaseURL(from base: URL) -> URL {
        var url = base
        let path = url.path
        if path.isEmpty || path == "/" {
            return url.appending(path: "v1")
        }
        if path.hasSuffix("/v1") || path == "/v1" {
            return url
        }
        if !path.contains("/v1") {
            return url.appending(path: "v1")
        }
        return url
    }

    static func url(base: URL, path: String) -> URL? {
        let root = v1BaseURL(from: base)
        let trimmed = path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return root.appending(path: trimmed)
    }
}
