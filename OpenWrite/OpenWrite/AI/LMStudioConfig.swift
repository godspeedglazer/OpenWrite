import Foundation

/// Recommended embedding models for LM Studio (user downloads separately).
enum EmbeddingModelPreset: String, CaseIterable, Identifiable, Sendable {
    case uaeLargeV1 = "WhereIsAI/UAE-Large-V1"
    case nomicEmbedText = "text-embedding-nomic-embed-text-v1.5"
    case bgeSmall = "BAAI/bge-small-en-v1.5"

    var id: String { rawValue }

    var menuTitle: String {
        switch self {
        case .uaeLargeV1:
            return "UAE-Large-V1 (recommended)"
        case .nomicEmbedText:
            return "Nomic Embed Text v1.5"
        case .bgeSmall:
            return "BGE Small EN v1.5"
        }
    }

    static var defaultPreset: EmbeddingModelPreset { .uaeLargeV1 }
}

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
        embeddingModel: String = EmbeddingModelPreset.defaultPreset.rawValue,
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

    /// Default embedding model id (Reor-style UAE-Large-V1 via LM Studio).
    static let defaultEmbeddingModelID = EmbeddingModelPreset.defaultPreset.rawValue

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

    /// Sidebar / settings display for the chat completions model.
    var chatModelDisplay: String {
        let trimmed = chatModel.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? "Not set" : trimmed
    }

    /// Sidebar / settings display for the embeddings model (falls back to chat model when blank).
    var embeddingModelDisplay: String {
        let trimmed = embeddingModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty { return trimmed }
        let chat = chatModel.trimmingCharacters(in: .whitespacesAndNewlines)
        if chat.isEmpty { return "Same as chat model" }
        return "\(chat) (same as chat)"
    }

    var usesDedicatedEmbeddingModel: Bool {
        !embeddingModel.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

/// High-level AI pipeline phase for chat and indexing UI.
enum AIActivityState: Equatable, Sendable {
    case idle
    case connecting
    case indexing
    case retrieving
    case streaming
    case error(String)

    var isBusy: Bool {
        switch self {
        case .idle, .error:
            return false
        case .connecting, .indexing, .retrieving, .streaming:
            return true
        }
    }

    var statusMessage: String? {
        switch self {
        case .idle:
            return nil
        case .connecting:
            return "Connecting to LM Studio…"
        case .indexing:
            return "Indexing vault…"
        case .retrieving:
            return "Searching vault…"
        case .streaming:
            return "Calling chat model…"
        case .error(let message):
            return message
        }
    }

    var shortLabel: String {
        switch self {
        case .idle: return "Idle"
        case .connecting: return "Connecting"
        case .indexing: return "Indexing"
        case .retrieving: return "Retrieving"
        case .streaming: return "Streaming"
        case .error: return "Error"
        }
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
