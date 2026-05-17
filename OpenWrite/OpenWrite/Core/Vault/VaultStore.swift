import Foundation
import Combine

@MainActor
final class VaultStore: ObservableObject {
    @Published var documents: [VaultDocument] = []
    @Published var selectedDocumentID: UUID?
    @Published var typeRegistry: PageTypeRegistry = .default

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

    // MARK: - Mutations (in-memory; Codable-ready for encrypted bundle)

    func createDocument(
        pageType: PageType,
        title: String? = nil,
        fromTemplate: Bool = true
    ) -> VaultDocument {
        let template = TypeTemplate.template(for: pageType, title: title)
        let doc: VaultDocument = fromTemplate
            ? .fromTemplate(template)
            : VaultDocument(title: title ?? pageType.displayName, pageType: pageType)
        documents.append(doc)
        selectedDocumentID = doc.id
        return doc
    }

    func updateDocument(_ document: VaultDocument) {
        guard let index = documents.firstIndex(where: { $0.id == document.id }) else { return }
        var updated = document
        updated.touchUpdatedAt()
        documents[index] = updated
    }

    func setPageType(_ pageType: PageType, for documentID: UUID, applyTemplate: Bool = false) {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        var doc = documents[index]
        let previousTitle = doc.displayTitle
        doc.pageType = pageType
        if applyTemplate {
            let template = TypeTemplate.template(for: pageType, title: previousTitle)
            doc.applyTemplate(template, preserveTitle: true)
        } else {
            var merged = PageProperties.defaults(for: pageType, title: previousTitle)
            for key in PageProperties.schema(for: pageType) {
                if let existing = doc.properties[key] {
                    merged[key] = existing
                }
            }
            doc.properties = merged
            doc.properties.setText(previousTitle, for: .title)
        }
        doc.touchUpdatedAt()
        documents[index] = doc
    }

    func setProperties(_ properties: PageProperties, for documentID: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        var doc = documents[index]
        doc.properties = properties
        let titleFromProps = properties.string(for: .title)
        if !titleFromProps.isEmpty {
            doc.title = titleFromProps
        }
        doc.touchUpdatedAt()
        documents[index] = doc
    }

    func syncPropertiesToNDL(for documentID: UUID) {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        var doc = documents[index]
        let propertyBlocks = NDLSerializer.propertyBlocks(from: doc.properties, pageType: doc.pageType)
        let body = doc.rootBlocks.filter { $0.kind != .property }
        doc.rootBlocks = propertyBlocks + body
        doc.touchUpdatedAt()
        documents[index] = doc
    }

    func updatePlainText(for documentID: UUID, plainText: String) {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        var doc = documents[index]
        doc.applyPlainText(plainText)
        documents[index] = doc
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
        store.documents.append(
            VaultDocument.fromTemplate(TypeTemplate.template(for: .task, title: "Ship typed pages"))
        )
        return store
    }()
}
