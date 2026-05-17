import Foundation
import Combine

@MainActor
final class VaultStore: ObservableObject {
    @Published var documents: [VaultDocument] = []
    @Published var selectedDocumentID: UUID?

    private let encryption: EncryptionService

    init(encryption: EncryptionService = NoOpEncryptionService()) {
        self.encryption = encryption
        documents = [.welcomeSample]
        selectedDocumentID = documents.first?.id
    }

    var selectedDocument: VaultDocument? {
        guard let id = selectedDocumentID else { return nil }
        return documents.first { $0.id == id }
    }

    /// Stub: encode document → seal → would write to `.owdoc` on disk.
    func sealedPayload(for document: VaultDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let plain = try encoder.encode(document)
        return try encryption.seal(plain, associatedData: document.id.uuidString.data(using: .utf8))
    }

    static let preview: VaultStore = {
        let store = VaultStore()
        return store
    }()
}
