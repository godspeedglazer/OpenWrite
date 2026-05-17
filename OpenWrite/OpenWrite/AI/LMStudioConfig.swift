import Foundation

/// User-configurable LM Studio (OpenAI-compatible) endpoint.
struct LMStudioConfig: Codable, Hashable, Sendable {
    var baseURL: URL
    var model: String
    var apiKey: String?
    var timeoutSeconds: TimeInterval

    init(
        baseURL: URL = URL(string: "http://127.0.0.1:1234")!,
        model: String = "local-model",
        apiKey: String? = nil,
        timeoutSeconds: TimeInterval = 60
    ) {
        self.baseURL = baseURL
        self.model = model
        self.apiKey = apiKey
        self.timeoutSeconds = timeoutSeconds
    }

    static let `default` = LMStudioConfig()

    var chatCompletionsURL: URL {
        baseURL.appending(path: "v1/chat/completions")
    }

    var modelsURL: URL {
        baseURL.appending(path: "v1/models")
    }
}
