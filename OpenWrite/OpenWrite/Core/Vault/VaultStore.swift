import Foundation
import Combine

@MainActor
final class VaultStore: ObservableObject {
    @Published var documents: [VaultDocument] = []
    @Published var selectedDocumentID: UUID?
    @Published var databases: [OWDatabase] = []
    @Published var databaseEntries: [OWDatabaseEntry] = []
    @Published var selectedDatabaseID: UUID?
    @Published var typeRegistry: PageTypeRegistry = .default
    @Published var vaults: [OpenWriteVault] = OpenWriteVault.builtIn
    @Published var activeVaultID: UUID = OpenWriteVault.primaryID

    private let encryption: EncryptionService

    init(encryption: EncryptionService = NoOpEncryptionService()) {
        self.encryption = encryption
        documents = [.welcomeSample]
        selectedDocumentID = nil
        databases = []
        databaseEntries = []
        bootstrapOnLaunch()
    }

    var activeVault: OpenWriteVault {
        vaults.first { $0.id == activeVaultID } ?? .primary
    }

    var isDemoVaultInstalled: Bool {
        DemoVaultSeeder.isDemoInstalled(in: documents)
    }

    var documentsInActiveVault: [VaultDocument] {
        documents(in: activeVaultID)
    }

    func documents(in vaultID: UUID) -> [VaultDocument] {
        documents.filter { $0.belongsToVault(vaultID) }
    }

    var selectedDocument: VaultDocument? {
        guard let id = selectedDocumentID else { return nil }
        return documents.first { $0.id == id }
    }

    var selectedDatabase: OWDatabase? {
        guard let id = selectedDatabaseID else { return nil }
        return databases.first { $0.id == id }
    }

    func entries(for databaseID: UUID) -> [OWDatabaseEntry] {
        databaseEntries
            .filter { $0.databaseID == databaseID }
            .sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Mutations (in-memory; Codable-ready for encrypted bundle)

    func createDocument(
        pageType: PageType,
        title: String? = nil,
        fromTemplate: Bool = true,
        vaultID: UUID? = nil
    ) -> VaultDocument {
        let template = TypeTemplate.template(for: pageType, title: title)
        var doc: VaultDocument = fromTemplate
            ? .fromTemplate(template)
            : VaultDocument(title: title ?? pageType.displayName, pageType: pageType)
        doc.assignVault(vaultID ?? activeVaultID)
        documents.append(doc)
        selectedDocumentID = doc.id
        return doc
    }

    /// Creates a root page from a structure preset and optional child pages (wiki site, collection).
    @discardableResult
    func createFromStructure(
        _ structure: StructureTemplate,
        title: String? = nil
    ) -> VaultDocument {
        let rootTitle = title ?? structure.displayName
        let template = TypeTemplate.template(for: structure, title: rootTitle)
        var root = VaultDocument.fromTemplate(template)
        root.assignVault(activeVaultID)
        root.metadata[StructureTemplate.MetadataKey.structureTemplate] = structure.rawValue

        let childSpecs = structure.childPageSpecs(rootTitle: rootTitle)
        var childIDs: [UUID] = []

        for spec in childSpecs {
            let childBlocks: [NoteBlock] = if let outline = spec.outline {
                StructureTemplate.blocks(from: outline)
            } else {
                [
                    NoteBlock(kind: .heading1, text: spec.title),
                    NoteBlock(kind: .paragraph, text: "")
                ]
            }
            var child = VaultDocument(
                title: spec.title,
                pageType: spec.pageType,
                properties: PageProperties.defaults(for: spec.pageType, title: spec.title),
                rootBlocks: childBlocks
            )
            child.assignVault(activeVaultID)
            child.metadata[StructureTemplate.MetadataKey.parentDocumentID] = root.id.uuidString
            child.metadata[StructureTemplate.MetadataKey.structureTemplate] = structure.rawValue
            childIDs.append(child.id)
            documents.append(child)
        }

        if !childIDs.isEmpty {
            root.metadata[StructureTemplate.MetadataKey.childDocumentIDs] = childIDs
                .map(\.uuidString)
                .joined(separator: ",")
            let childTitles = childSpecs.map(\.title)
            root.rootBlocks = structure.makeRootBlocks(title: rootTitle, childTitles: childTitles)
        }

        documents.append(root)
        selectedDocumentID = root.id
        return root
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

    func updateRootBlocks(for documentID: UUID, bodyBlocks: [NoteBlock]) {
        guard let index = documents.firstIndex(where: { $0.id == documentID }) else { return }
        var doc = documents[index]
        let propertyBlocks = doc.rootBlocks.filter { $0.kind == .property }
        doc.rootBlocks = propertyBlocks + bodyBlocks
        doc.touchUpdatedAt()
        documents[index] = doc
    }

    /// Stub: encode document → seal → would write to `.owdoc` on disk.
    func sealedPayload(for document: VaultDocument) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let plain = try encoder.encode(document)
        return try encryption.seal(plain, associatedData: document.id.uuidString.data(using: .utf8))
    }

    // MARK: - Universal databases

    @discardableResult
    func createDatabase(
        preset: DatabasePreset,
        name: String? = nil
    ) -> OWDatabase {
        let database = preset.makeDatabase(name: name)
        databases.append(database)
        selectedDatabaseID = database.id
        selectedDocumentID = nil
        return database
    }

    @discardableResult
    func createDatabase(_ database: OWDatabase) -> OWDatabase {
        var db = database
        db.touchUpdatedAt()
        databases.append(db)
        selectedDatabaseID = db.id
        selectedDocumentID = nil
        return db
    }

    func updateDatabase(_ database: OWDatabase) {
        guard let index = databases.firstIndex(where: { $0.id == database.id }) else { return }
        var updated = database
        updated.touchUpdatedAt()
        databases[index] = updated
    }

    func deleteDatabase(id: UUID) {
        databases.removeAll { $0.id == id }
        databaseEntries.removeAll { $0.databaseID == id }
        reconcileSelections()
    }

    @discardableResult
    func addDatabaseEntry(to databaseID: UUID) -> OWDatabaseEntry? {
        guard let database = databases.first(where: { $0.id == databaseID }) else { return nil }
        let entry = OWDatabaseEntry.emptyRow(for: database)
        databaseEntries.append(entry)
        return entry
    }

    func updateDatabaseEntry(_ entry: OWDatabaseEntry) {
        guard let index = databaseEntries.firstIndex(where: { $0.id == entry.id }) else { return }
        var updated = entry
        updated.touchUpdatedAt()
        databaseEntries[index] = updated
        if let dbIndex = databases.firstIndex(where: { $0.id == entry.databaseID }) {
            databases[dbIndex].touchUpdatedAt()
        }
    }

    func deleteDatabaseEntry(id: UUID) {
        databaseEntries.removeAll { $0.id == id }
    }

    // MARK: - Snapshot (future `.openwrite` bundle)

    func makeSnapshot() -> VaultSnapshot {
        VaultSnapshot(
            documents: documents,
            databases: databases,
            databaseEntries: databaseEntries
        )
    }

    func applySnapshot(_ snapshot: VaultSnapshot) {
        documents = snapshot.documents
        databases = snapshot.databases
        databaseEntries = snapshot.databaseEntries
        reconcileSelections()
    }

    // MARK: - Vault switching & demo seed

    /// First launch: install demo once. Safe to call on every launch — skips when already seeded.
    func bootstrapOnLaunch() {
        let shouldOfferFirstLaunchDemo = !VaultLaunchPreferences.didSeedDemoOnFirstLaunch
        if shouldOfferFirstLaunchDemo {
            VaultLaunchPreferences.didSeedDemoOnFirstLaunch = true
            _ = installDemoVault(selectHub: false)
        }
        reconcileSelections()
        if selectedDocumentID == nil {
            if documents.contains(where: { $0.id == VaultDocument.welcomeDocumentID && $0.belongsToVault(activeVaultID) }) {
                selectedDocumentID = VaultDocument.welcomeDocumentID
            } else if let first = documents(in: activeVaultID).first {
                selectedDocumentID = first.id
            }
        }
    }

    /// Idempotent demo install. Returns `true` when new pages were added.
    @discardableResult
    func installDemoVault(selectHub: Bool = true) -> Bool {
        guard !isDemoVaultInstalled else { return false }

        let existingIDs = Set(documents.map(\.id))
        let toAdd = DemoVaultSeeder.documents().filter { !existingIDs.contains($0.id) }
        guard !toAdd.isEmpty else { return false }

        documents.append(contentsOf: toAdd)
        if !vaults.contains(where: { $0.id == OpenWriteVault.demoID }) {
            vaults.append(.demo)
        }
        if selectHub {
            activeVaultID = OpenWriteVault.demoID
            selectedDocumentID = DemoVaultSeeder.hubDocumentID
            selectedDatabaseID = nil
        }
        reconcileSelections()
        return true
    }

    func switchVault(to vaultID: UUID) {
        guard vaults.contains(where: { $0.id == vaultID }) else { return }
        activeVaultID = vaultID
        if let selected = selectedDocumentID,
           !documents.contains(where: { $0.id == selected && $0.belongsToVault(vaultID) }) {
            selectedDocumentID = documents(in: vaultID).first?.id
        }
        if selectedDocumentID == nil {
            selectedDocumentID = documents(in: vaultID).first?.id
        }
        selectedDatabaseID = nil
        reconcileSelections()
    }

    /// Clears stale document/database selection after deletes, snapshot import, or empty vault.
    func reconcileSelections() {
        if let id = selectedDocumentID,
           !documents.contains(where: { $0.id == id && $0.belongsToVault(activeVaultID) }) {
            selectedDocumentID = documents(in: activeVaultID).first?.id
        }
        if let id = selectedDocumentID,
           !documents.contains(where: { $0.id == id }) {
            selectedDocumentID = documents(in: activeVaultID).first?.id
        }
        if let id = selectedDatabaseID,
           !databases.contains(where: { $0.id == id }) {
            selectedDatabaseID = databases.first?.id
        }
        if documents.isEmpty {
            selectedDocumentID = nil
        }
        if databases.isEmpty {
            selectedDatabaseID = nil
        }
    }

    func encodedSnapshot() throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.sortedKeys]
        return try encoder.encode(makeSnapshot())
    }

    static let preview: VaultStore = {
        let store = VaultStore()
        store.documents.append(
            VaultDocument.fromTemplate(TypeTemplate.template(for: .task, title: "Ship typed pages"))
        )
        let snippets = store.createDatabase(preset: .codeSnippets)
        var entry = OWDatabaseEntry.emptyRow(for: snippets)
        if let titleField = snippets.fields.first(where: { $0.key == "title" }) {
            entry.setValue(.text("Hello, OpenWrite"), for: titleField)
        }
        if let bodyField = snippets.fields.first(where: { $0.key == "body" }) {
            entry.setValue(.code("print(\"Hello\")"), for: bodyField)
        }
        store.databaseEntries.append(entry)
        return store
    }()
}
