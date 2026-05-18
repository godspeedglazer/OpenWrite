import Foundation

protocol EmbeddingService: Sendable {
    func embed(text: String) async throws -> [Float]
}

/// Deterministic local vectors when LM Studio embeddings are unavailable.
struct LocalHashEmbeddingService: EmbeddingService {
    let dimensions: Int

    init(dimensions: Int = AISafetyLimits.embeddingDimensions) {
        self.dimensions = dimensions
    }

    func embed(text: String) async throws -> [Float] {
        let normalized = text
            .lowercased()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        let capped = String(normalized.prefix(AISafetyLimits.maxEmbeddingInputChars))
        guard !capped.isEmpty else {
            return [Float](repeating: 0, count: dimensions)
        }

        var vector = [Float](repeating: 0, count: dimensions)
        let tokens = capped.split { !$0.isLetter && !$0.isNumber }.map(String.init)
        for token in tokens {
            var hash = token.utf8.reduce(UInt64(token.count)) { acc, byte in
                (acc &* 1_099_511_628_289) ^ UInt64(byte)
            }
            for _ in 0 ..< 4 {
                let index = Int(hash % UInt64(dimensions))
                let sign: Float = (hash & 1) == 0 ? 1 : -1
                vector[index] += sign
                hash = (hash &* 1_099_511_628_289) ^ (hash >> 17)
            }
        }

        let norm = sqrt(vector.reduce(0) { $0 + $1 * $1 })
        if norm > 0 {
            vector = vector.map { $0 / norm }
        }
        return vector
    }
}

extension Notification.Name {
    /// User-facing notice when LM Studio embeddings are skipped (posted at most once per cooldown window).
    static let openWriteEmbeddingUnreachable = Notification.Name("com.openwrite.embeddingUnreachable")
}

/// Cooldown after connection failures so indexing does not open parallel `/v1/embeddings` storms.
actor LMStudioEmbeddingCircuit {
    static let shared = LMStudioEmbeddingCircuit()

    private var disabledUntil: Date?
    private var lastNoticeAt: Date?

    func shouldAttemptRemote() -> Bool {
        guard let until = disabledUntil else { return true }
        if Date() >= until {
            disabledUntil = nil
            return true
        }
        return false
    }

    func recordSuccess() {
        disabledUntil = nil
    }

    /// Opens the circuit on unreachable errors; returns a debounced user notice string when appropriate.
    func recordFailure(_ error: Error) -> String? {
        guard Self.isUnreachable(error) else { return nil }
        disabledUntil = Date().addingTimeInterval(AISafetyLimits.embeddingCircuitCooldownSeconds)
        let now = Date()
        if let last = lastNoticeAt,
           now.timeIntervalSince(last) < AISafetyLimits.embeddingUnreachableNoticeIntervalSeconds {
            return nil
        }
        lastNoticeAt = now
        return "LM Studio unreachable — using local embedding fallback."
    }

    static func isUnreachable(_ error: Error) -> Bool {
        if error is AITaskTimeoutError { return true }
        if let urlError = error as? URLError {
            switch urlError.code {
            case .cannotConnectToHost, .cannotFindHost, .networkConnectionLost,
                 .notConnectedToInternet, .timedOut, .dnsLookupFailed:
                return true
            default:
                break
            }
        }
        if let lm = error as? LMStudioError {
            switch lm {
            case .invalidURL, .embeddingsUnavailable:
                return true
            case .httpStatus(let code, _):
                return code == 502 || code == 503 || code == 504
            default:
                break
            }
        }
        let description = error.localizedDescription.lowercased()
        return description.contains("connection refused")
            || description.contains("could not connect")
            || description.contains("network")
    }
}

/// Caps concurrent embedding HTTP calls app-wide (indexing + retrieval share this gate).
/// With `LMStudioEmbeddingCircuit`, prevents a launch-time storm of parallel `/v1/embeddings` when :1234 is down.
actor EmbeddingRequestGate {
    static let shared = EmbeddingRequestGate()

    private var inFlight = 0
    private let maxConcurrent = 2 // P0: max 1–2 concurrent embeds; remainder waits or uses hash fallback via circuit

    func withPermit<T: Sendable>(_ operation: @Sendable () async throws -> T) async throws -> T {
        while inFlight >= maxConcurrent {
            try await Task.sleep(nanoseconds: 30_000_000)
            try Task.checkCancellation()
        }
        inFlight += 1
        defer { inFlight -= 1 }
        return try await operation()
    }
}

struct LMStudioEmbeddingService: EmbeddingService {
    let client: LMStudioClient
    let fallback: EmbeddingService

    init(client: LMStudioClient, fallback: EmbeddingService = LocalHashEmbeddingService()) {
        self.client = client
        self.fallback = fallback
    }

    func embed(text: String) async throws -> [Float] {
        try await EmbeddingRequestGate.shared.withPermit {
            try await embedGated(text: text)
        }
    }

    private func embedGated(text: String) async throws -> [Float] {
        guard await LMStudioEmbeddingCircuit.shared.shouldAttemptRemote() else {
            return try await fallback.embed(text: text)
        }

        do {
            let vector = try await AITaskTimeout.run(
                seconds: AISafetyLimits.indexingEmbeddingTimeoutSeconds
            ) {
                try await client.embeddings(input: text)
            }
            await LMStudioEmbeddingCircuit.shared.recordSuccess()
            return vector
        } catch is CancellationError {
            throw CancellationError()
        } catch {
            if let notice = await LMStudioEmbeddingCircuit.shared.recordFailure(error) {
                await MainActor.run {
                    NotificationCenter.default.post(
                        name: .openWriteEmbeddingUnreachable,
                        object: nil,
                        userInfo: ["message": notice]
                    )
                }
            }
            return try await fallback.embed(text: text)
        }
    }
}
