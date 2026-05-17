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

struct LMStudioEmbeddingService: EmbeddingService {
    let client: LMStudioClient
    let fallback: EmbeddingService

    init(client: LMStudioClient, fallback: EmbeddingService = LocalHashEmbeddingService()) {
        self.client = client
        self.fallback = fallback
    }

    func embed(text: String) async throws -> [Float] {
        do {
            return try await client.embeddings(input: text)
        } catch LMStudioError.embeddingsUnavailable {
            return try await fallback.embed(text: text)
        } catch {
            return try await fallback.embed(text: text)
        }
    }
}
