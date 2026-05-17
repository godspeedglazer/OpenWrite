import Foundation

/// Minimal HTTP client for LM Studio's OpenAI-compatible API.
struct LMStudioClient: Sendable {
    let config: LMStudioConfig

    func healthCheck() async throws -> Bool {
        var request = URLRequest(url: config.modelsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = min(config.timeoutSeconds, 10)
        if let key = config.apiKey, !key.isEmpty {
            request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
        }

        let (_, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { return false }
        return (200 ..< 300).contains(http.statusCode)
    }
}
