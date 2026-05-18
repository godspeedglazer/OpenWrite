import Foundation

enum LMStudioError: Error, LocalizedError, Sendable {
    case disabled
    case invalidURL
    case httpStatus(Int, String?)
    case decodeFailed
    case emptyResponse
    case payloadTooLarge
    case embeddingsUnavailable

    var errorDescription: String? {
        switch self {
        case .disabled:
            return "AI features are disabled."
        case .invalidURL:
            return "Invalid LM Studio base URL. Use http://127.0.0.1:1234"
        case .httpStatus(let code, let detail):
            if let detail, !detail.isEmpty {
                return "LM Studio HTTP \(code): \(detail)"
            }
            return "LM Studio HTTP \(code)"
        case .decodeFailed:
            return "Could not parse LM Studio response"
        case .emptyResponse:
            return "LM Studio returned an empty reply"
        case .payloadTooLarge:
            return "Context is too large for the model. Try a shorter question."
        case .embeddingsUnavailable:
            return "Embeddings endpoint is not available on this server"
        }
    }
}

struct LMStudioModel: Identifiable, Hashable, Sendable {
    let id: String
    let ownedBy: String?
}

/// OpenAI-compatible LM Studio REST client.
struct LMStudioClient: Sendable {
    let config: LMStudioConfig
    private let session: URLSession

    init(config: LMStudioConfig, session: URLSession? = nil) {
        self.config = config
        if let session {
            self.session = session
        } else {
            let configuration = URLSessionConfiguration.ephemeral
            configuration.timeoutIntervalForRequest = config.timeoutSeconds
            configuration.timeoutIntervalForResource = config.timeoutSeconds
            configuration.waitsForConnectivity = false
            self.session = URLSession(configuration: configuration)
        }
    }

    func healthCheck() async throws -> Bool {
        _ = try await listModels()
        return true
    }

    func listModels() async throws -> [LMStudioModel] {
        var request = URLRequest(url: config.modelsURL)
        request.httpMethod = "GET"
        request.timeoutInterval = min(config.timeoutSeconds, 15)
        applyAuth(&request)

        let (data, response) = try await session.data(for: request)
        try validateHTTP(response: response, data: data)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let dataArray = json["data"] as? [[String: Any]]
        else {
            throw LMStudioError.decodeFailed
        }

        return dataArray.compactMap { entry in
            guard let id = entry["id"] as? String else { return nil }
            return LMStudioModel(id: id, ownedBy: entry["owned_by"] as? String)
        }
    }

    func chat(
        systemPrompt: String,
        userMessage: String,
        maxTokens: Int = AISafetyLimits.maxCompletionTokens
    ) async throws -> String {
        let messages: [[String: String]] = [
            ["role": "system", "content": systemPrompt],
            ["role": "user", "content": userMessage]
        ]
        var full = ""
        for try await delta in chatCompletionsStream(messages: messages, maxTokens: maxTokens) {
            full += delta
        }
        let trimmed = full.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { throw LMStudioError.emptyResponse }
        return trimmed
    }

    func chatCompletionsStream(
        messages: [[String: String]],
        maxTokens: Int = AISafetyLimits.maxCompletionTokens,
        temperature: Double = 0.2
    ) -> AsyncThrowingStream<String, Error> {
        AsyncThrowingStream { continuation in
            let task = Task {
                do {
                    try await self.streamChat(
                        messages: messages,
                        maxTokens: maxTokens,
                        temperature: temperature,
                        continuation: continuation
                    )
                    continuation.finish()
                } catch {
                    continuation.finish(throwing: error)
                }
            }
            continuation.onTermination = { _ in
                task.cancel()
            }
        }
    }

    /// Embeddings API; throws `embeddingsUnavailable` when the server has no `/embeddings`.
    func embeddings(input: String) async throws -> [Float] {
        let model = config.resolvedEmbeddingModel
        guard !model.isEmpty else { throw LMStudioError.embeddingsUnavailable }

        var request = URLRequest(url: config.embeddingsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.timeoutInterval = min(
            config.timeoutSeconds,
            AISafetyLimits.retrievalEmbeddingTimeoutSeconds
        )
        applyAuth(&request)

        let body: [String: Any] = [
            "model": model,
            "input": String(input.prefix(AISafetyLimits.maxEmbeddingInputChars))
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LMStudioError.decodeFailed
        }
        if http.statusCode == 404 {
            throw LMStudioError.embeddingsUnavailable
        }
        try validateHTTP(response: response, data: data)

        guard
            let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
            let rows = json["data"] as? [[String: Any]],
            let first = rows.first,
            let vector = first["embedding"] as? [Double]
        else {
            throw LMStudioError.decodeFailed
        }
        return vector.map(Float.init)
    }

    private func streamChat(
        messages: [[String: String]],
        maxTokens: Int,
        temperature: Double,
        continuation: AsyncThrowingStream<String, Error>.Continuation
    ) async throws {
        let model = config.chatModel.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !model.isEmpty else { throw LMStudioError.decodeFailed }

        let promptEstimate = messages.reduce(0) { partial, message in
            partial + AIInput.estimatedTokenCount(for: message["content"] ?? "")
        }
        let budget = AISafetyLimits.maxEstimatedPromptTokens + maxTokens
        guard promptEstimate <= budget else { throw LMStudioError.payloadTooLarge }

        var request = URLRequest(url: config.chatCompletionsURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("text/event-stream", forHTTPHeaderField: "Accept")
        request.timeoutInterval = min(
            config.timeoutSeconds,
            AISafetyLimits.chatStreamTimeoutSeconds
        )
        applyAuth(&request)

        let body: [String: Any] = [
            "model": model,
            "messages": messages,
            "temperature": temperature,
            "max_tokens": maxTokens,
            "stream": true
        ]
        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (bytes, response) = try await session.bytes(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw LMStudioError.decodeFailed
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            var collected = Data()
            for try await byte in bytes {
                collected.append(byte)
                if collected.count > 16_384 { break }
            }
            throw LMStudioError.httpStatus(http.statusCode, Self.errorDetail(from: collected))
        }

        var lineData = Data()
        var yieldedContent = false
        for try await byte in bytes {
            try Task.checkCancellation()
            if byte == UInt8(ascii: "\n") {
                guard let line = String(data: lineData, encoding: .utf8)?
                    .trimmingCharacters(in: .whitespacesAndNewlines),
                    !line.isEmpty
                else {
                    lineData.removeAll(keepingCapacity: true)
                    continue
                }
                lineData.removeAll(keepingCapacity: true)
                if let delta = Self.parseSSEDataLine(line), !delta.isEmpty {
                    yieldedContent = true
                    continuation.yield(delta)
                }
            } else {
                lineData.append(byte)
            }
        }
        if !lineData.isEmpty,
           let line = String(data: lineData, encoding: .utf8),
           let delta = Self.parseSSEDataLine(line),
           !delta.isEmpty {
            yieldedContent = true
            continuation.yield(delta)
        }
        guard yieldedContent else { throw LMStudioError.emptyResponse }
    }

    private func validateHTTP(response: URLResponse, data: Data) throws {
        guard let http = response as? HTTPURLResponse else {
            throw LMStudioError.decodeFailed
        }
        guard (200 ..< 300).contains(http.statusCode) else {
            throw LMStudioError.httpStatus(http.statusCode, Self.errorDetail(from: data))
        }
    }

    private func applyAuth(_ request: inout URLRequest) {
        guard let key = config.apiKey?.trimmingCharacters(in: .whitespacesAndNewlines), !key.isEmpty else {
            return
        }
        request.setValue("Bearer \(key)", forHTTPHeaderField: "Authorization")
    }

    private static func parseSSEDataLine(_ line: String) -> String? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("data:") else { return nil }
        let payload = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)
        if payload == "[DONE]" { return nil }
        guard
            let data = payload.data(using: .utf8),
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let choices = json["choices"] as? [[String: Any]],
            let first = choices.first
        else { return nil }

        if let delta = first["delta"] as? [String: Any], let content = delta["content"] as? String {
            return content
        }
        if let message = first["message"] as? [String: Any], let content = message["content"] as? String {
            return content
        }
        return nil
    }

    private static func errorDetail(from data: Data) -> String? {
        guard
            let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
            let error = json["error"] as? [String: Any],
            let message = error["message"] as? String
        else { return nil }
        return message
    }
}
