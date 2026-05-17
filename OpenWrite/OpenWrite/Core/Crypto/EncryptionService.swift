import Foundation

/// Encrypts and decrypts vault payloads at rest.
protocol EncryptionService: Sendable {
    func seal(_ plaintext: Data, associatedData: Data?) throws -> Data
    func open(_ ciphertext: Data, associatedData: Data?) throws -> Data
}

/// Phase 1 pass-through stub — replace with CryptoKit AEAD in MVP.
struct NoOpEncryptionService: EncryptionService {
    func seal(_ plaintext: Data, associatedData: Data?) throws -> Data {
        plaintext
    }

    func open(_ ciphertext: Data, associatedData: Data?) throws -> Data {
        ciphertext
    }
}

enum VaultCryptoError: Error, LocalizedError {
    case notUnlocked
    case invalidCiphertext

    var errorDescription: String? {
        switch self {
        case .notUnlocked: return "Vault is locked."
        case .invalidCiphertext: return "Could not decrypt document."
        }
    }
}
