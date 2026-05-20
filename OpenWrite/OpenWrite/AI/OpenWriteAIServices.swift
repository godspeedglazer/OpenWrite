import Foundation
import Combine

@MainActor
final class OpenWriteAIServices: ObservableObject {
    enum LMConnectionState: Equatable {
        case notChecked
        case checking
        case connecting
        case connected
        case noModelLoaded
        case offline

        var shortLabel: String {
            switch self {
            case .notChecked: return "not checked"
            case .checking: return "checking…"
            case .connecting: return "connecting…"
            case .connected: return "connected"
            case .noModelLoaded: return "no model loaded"
            case .offline: return "not connected"
            }
        }

        var composerCaption: String {
            switch self {
            case .notChecked, .checking: return "checking…"
            case .connecting: return "connecting…"
            case .connected: return "connected"
            case .noModelLoaded: return "no model loaded"
            case .offline: return "LM Studio offline"
            }
        }

        /// Composer status pill — one label per `LMConnectionState` (no streaming override).
        var statusPillLabel: String {
            switch self {
            case .connected: return "Model loaded"
            case .noModelLoaded: return "No model loaded"
            case .offline: return "Offline"
            case .notChecked: return "Not checked"
            case .checking: return "Checking…"
            case .connecting: return "Connecting…"
            }
        }

        /// Visual tone for the chat composer connection pill.
        enum StatusPillTone: Equatable {
            case ready
            case warning
            case offline
            case pending
        }

        var statusPillTone: StatusPillTone {
            switch self {
            case .connected: return .ready
            case .noModelLoaded: return .warning
            case .offline: return .offline
            case .notChecked, .checking, .connecting: return .pending
            }
        }
    }

    @Published var lmConfig: LMStudioConfig = .default
    @Published var lmStatus: String = "Not checked"
    @Published var lmConnectionState: LMConnectionState = .notChecked
    @Published var availableModels: [LMStudioModel] = []
    /// Chat model instance actually loaded in LM Studio (from native `/api/v1/models`).
    @Published private(set) var activeChatModelID: String = ""
    @Published private(set) var activeChatModelDisplay: String = ""
    @Published var isIndexing = false
    @Published var indexedChunkCount = 0
    @Published var activityState: AIActivityState = .idle
    @Published var lastChatError: String?
    @Published var selectedAgentID: String = AgentRegistry.defaultAgent.id

    let dictation: DictationService = NoOpDictationService()
    let voiceInput = VoiceInputService()
    let vectorStore = InMemoryVectorStore()
    let ingestionHealth = IngestionHealthMonitor()

    private(set) var lmClient: LMStudioClient
    private(set) var embeddings: EmbeddingService
    private(set) var indexer: IndexerService
    private(set) var retrieval: RetrievalService
    private(set) var rag: RAGService
    let webFetch = WebFetchService()
    let webResearchCache = WebResearchSessionCache()

    private var ingestionPipeline: IngestionPipeline?
    private var indexingTask: Task<Void, Never>?
    private var connectionMonitorTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    /// Vault content signature reflected in the last successful `prepareVaultIndex` / `reindex`.
    private(set) var lastPreparedVaultSignature: Int?
    /// Per-document content fingerprints for incremental `index(document:)` after edits.
    private var indexedDocumentFingerprints: [UUID: Int] = [:]
    private var documentIndexTasks: [UUID: Task<Void, Never>] = [:]

    /// True after a successful connection check (`lmStatus` begins with "Connected").
    var isLMStudioConnected: Bool {
        lmConnectionState == .connected
    }

    /// Composer / status line model name — prefers in-memory loaded model over saved config id.
    var composerChatModelLabel: String {
        let live = activeChatModelDisplay.trimmingCharacters(in: .whitespacesAndNewlines)
        if !live.isEmpty { return live }
        return lmConfig.chatModelDisplay
    }

    /// User-facing connection suffix for the chat composer caption (`model · connected`).
    var modelConnectionLabel: String {
        if activityState == .streaming {
            return LMConnectionState.connected.composerCaption
        }
        if activityState == .connecting,
           lmConnectionState != .connected,
           lmConnectionState != .noModelLoaded {
            return LMConnectionState.connecting.composerCaption
        }
        return lmConnectionState.composerCaption
    }

    init() {
        let stored = LMStudioConfigPersistence.load() ?? .default
        lmConfig = stored
        lmClient = LMStudioClient(config: stored)
        embeddings = LocalHashEmbeddingService()
        indexer = NoOpIndexerService()
        retrieval = NoOpRetrievalService()
        rag = PlaceholderRAGService(retrieval: NoOpRetrievalService())
        vectorStore.attachHealth(ingestionHealth)
        ingestionHealth.objectWillChange
            .receive(on: DispatchQueue.main)
            .sink { [weak self] _ in self?.objectWillChange.send() }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: .openWriteEmbeddingUnreachable)
            .receive(on: DispatchQueue.main)
            .sink { [weak self] notification in
                guard let self else { return }
                let message = notification.userInfo?["message"] as? String
                    ?? "LM Studio unreachable — using local embedding fallback."
                if !lmStatus.localizedCaseInsensitiveContains("unreachable") {
                    lmStatus = message
                }
            }
            .store(in: &cancellables)
        rebuildPipeline()
    }

    /// Loads persisted vectors, then rebuilds the search index (serialized — avoids racing `loadFromDisk` with `rebuildAll`).
    func prepareVaultIndex(documents: [VaultDocument]) async {
        await vectorStore.loadFromDiskIfPresent()
        let loaded = await vectorStore.chunkCount
        indexedChunkCount = loaded
        ingestionHealth.updateIndexedChunkCount(loaded)
        let signature = Self.vaultContentSignature(documents: documents)
        if loaded > 0 {
            lastPreparedVaultSignature = signature
            applyIndexFingerprints(for: Self.indexEntries(including: documents))
            return
        }
        guard Self.hasIndexableContent(documents: documents) else { return }
        await reindex(documents: documents)
        lastPreparedVaultSignature = signature
    }

    static func vaultContentSignature(documents: [VaultDocument]) -> Int {
        var hasher = Hasher()
        for entry in indexEntries(including: documents) {
            hasher.combine(entryFingerprint(entry))
        }
        return hasher.finalize()
    }

    static func entryFingerprint(_ entry: VaultIndexEntry) -> Int {
        var hasher = Hasher()
        hasher.combine(entry.documentID)
        hasher.combine(entry.title)
        hasher.combine(entry.sourceFilename ?? "")
        if let updated = entry.documentUpdatedAt {
            hasher.combine(updated.timeIntervalSinceReferenceDate)
        }
        for block in entry.blocks {
            hasher.combine(block.id)
            hasher.combine(block.kind)
            hasher.combine(block.text)
            hasher.combine(block.isChecked)
        }
        return hasher.finalize()
    }

    private func applyIndexFingerprints(for entries: [VaultIndexEntry]) {
        indexedDocumentFingerprints = Dictionary(
            uniqueKeysWithValues: entries.map { ($0.documentID, Self.entryFingerprint($0)) }
        )
    }

    func shouldSkipDebouncedReindex(for signature: Int) -> Bool {
        guard indexedChunkCount > 0,
              let lastPreparedVaultSignature,
              lastPreparedVaultSignature == signature else { return false }
        return true
    }

    /// Pages plus on-disk `.md` under the vault root, deduped by stable document id.
    static func hasIndexableContent(documents: [VaultDocument]) -> Bool {
        !indexEntries(including: documents).isEmpty
    }

    func applyConfig(_ config: LMStudioConfig) {
        lmConfig = config
        LMStudioConfigPersistence.save(config)
        rebuildPipeline()
    }

    func applyBackendPreset(_ preset: AIBackendPreset) {
        var config = lmConfig
        config.backendPreset = preset
        if preset != .custom {
            config.baseURL = preset.defaultBaseURL
        }
        applyConfig(config)
    }

    func updateChatModel(_ modelID: String) {
        lmConfig.chatModel = modelID
        LMStudioConfigPersistence.save(lmConfig)
        rebuildPipeline()
    }

    func updateEmbeddingModel(_ modelID: String) {
        lmConfig.embeddingModel = modelID
        LMStudioConfigPersistence.save(lmConfig)
        rebuildPipeline()
    }

    func rebuildPipeline() {
        lmClient = LMStudioClient(config: lmConfig)
        embeddings = LMStudioEmbeddingService(
            client: lmClient,
            fallback: LocalHashEmbeddingService()
        )
        let pipeline = IngestionPipeline(
            vectorStore: vectorStore,
            embeddings: embeddings,
            health: ingestionHealth
        )
        ingestionPipeline = pipeline
        indexer = PipelineIndexerService(pipeline: pipeline)
        retrieval = HybridRetrievalService(vectorStore: vectorStore, embeddings: embeddings)
        rag = LiveRAGService(retrieval: retrieval, client: lmClient)
    }

    var selectedAgent: AgentConfig {
        AgentRegistry.agent(id: selectedAgentID)
    }

    func setActivity(_ state: AIActivityState) {
        activityState = state
        if state == .connecting,
           lmConnectionState == .notChecked || lmConnectionState == .offline {
            lmConnectionState = .connecting
        }
        if case .error = state { return }
        if state != .idle { lastChatError = nil }
    }

    func cancelIndexing() {
        indexingTask?.cancel()
        Task {
            await indexer.cancel()
            isIndexing = false
            if case .indexing = activityState {
                setActivity(.idle)
            }
        }
    }

    /// Polls LM Studio while the app is open so load/unload is reflected without relaunching.
    func startConnectionMonitoring(intervalSeconds: TimeInterval = 18) {
        connectionMonitorTask?.cancel()
        connectionMonitorTask = Task { [weak self] in
            while !Task.isCancelled {
                guard let self else { return }
                await self.checkConnection(silent: true)
                let delay = UInt64(max(intervalSeconds, 8) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: delay)
            }
        }
    }

    func stopConnectionMonitoring() {
        connectionMonitorTask?.cancel()
        connectionMonitorTask = nil
    }

    func checkConnection(silent: Bool = false) async {
        if !silent {
            lmConnectionState = .checking
            setActivity(.connecting)
            lmStatus = "Checking…"
        }
        do {
            let models = try await lmClient.listModels()
            availableModels = models
            let nativeModels = (try? await lmClient.listNativeModels()) ?? []
            syncActiveChatModel(nativeModels: nativeModels, catalogModels: models)
            if !silent {
                setActivity(.idle)
            }
        } catch {
            availableModels = []
            activeChatModelID = ""
            activeChatModelDisplay = ""
            lmStatus = "Error: \(error.localizedDescription)"
            lmConnectionState = .offline
            if silent {
                if case .error = activityState {
                    // Keep an active user-facing error until the next explicit check.
                } else if activityState == .streaming || activityState == .connecting {
                    // Do not clobber an in-flight chat session.
                } else {
                    setActivity(.idle)
                }
            } else {
                setActivity(.error(Self.actionableConnectionError(error)))
            }
        }
    }

    /// Refreshes loaded-model display from LM Studio (call before showing model name in chat steppers).
    func refreshLoadedChatModel() async {
        await checkConnection(silent: true)
    }

    private func syncActiveChatModel(
        nativeModels: [LMStudioNativeModel],
        catalogModels: [LMStudioModel]
    ) {
        let loadedLLMs = nativeModels.filter { $0.type == "llm" && $0.isLoaded }

        // Native `/api/v1/models` is authoritative — never treat OpenAI catalog membership as "loaded".
        if !nativeModels.isEmpty {
            if let active = Self.pickLoadedChatModel(
                loadedLLMs: loadedLLMs,
                preferredID: lmConfig.chatModel
            ) {
                let instanceID = active.activeInstanceID ?? active.key
                activeChatModelID = instanceID
                activeChatModelDisplay = active.displayName

                if instanceID != lmConfig.chatModel {
                    lmConfig.chatModel = instanceID
                    LMStudioConfigPersistence.save(lmConfig)
                    rebuildPipeline()
                }
                lmStatus = "Connected · \(active.displayName)"
                lmConnectionState = .connected
                return
            }

            activeChatModelID = ""
            activeChatModelDisplay = ""
            lmStatus = "Connected — load a chat model in LM Studio"
            lmConnectionState = .noModelLoaded
            return
        }

        // Ollama / servers without native load metadata — catalog fallback only.
        activeChatModelID = ""
        activeChatModelDisplay = ""

        if catalogModels.isEmpty {
            lmStatus = "Connected (no models listed)"
            lmConnectionState = .noModelLoaded
            return
        }

        if let resolved = Self.resolveChatModelID(
            current: lmConfig.chatModel,
            available: catalogModels.map(\.id)
        ), resolved != lmConfig.chatModel {
            lmConfig.chatModel = resolved
            LMStudioConfigPersistence.save(lmConfig)
            rebuildPipeline()
        }
        applyLMConnectionStateFromCatalog(catalogModels)
    }

    private func applyLMConnectionStateFromCatalog(_ models: [LMStudioModel]) {
        if models.isEmpty {
            lmStatus = "Connected (no models listed)"
            lmConnectionState = .noModelLoaded
            return
        }
        let chatID = lmConfig.chatModel.trimmingCharacters(in: .whitespacesAndNewlines)
        let modelIDs = models.map(\.id)
        if !chatID.isEmpty, !modelIDs.contains(chatID) {
            lmStatus = "Connected — load “\(LMStudioConfig.displayLabel(for: chatID))” on the server"
            lmConnectionState = .noModelLoaded
        } else {
            if !chatID.isEmpty {
                activeChatModelDisplay = LMStudioConfig.displayLabel(for: chatID)
                activeChatModelID = chatID
            }
            lmStatus = "Connected · \(models.count) model\(models.count == 1 ? "" : "s") in catalog"
            lmConnectionState = .connected
        }
    }

    /// Picks the in-memory loaded model; prefers saved config only when that id is actually loaded.
    static func pickLoadedChatModel(
        loadedLLMs: [LMStudioNativeModel],
        preferredID: String
    ) -> LMStudioNativeModel? {
        guard !loadedLLMs.isEmpty else { return nil }
        let pref = preferredID.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pref.isEmpty,
           let match = loadedLLMs.first(where: { model in
               model.loadedInstanceIDs.contains(pref)
                   || model.key == pref
                   || model.loadedInstanceIDs.contains(where: { $0 == pref })
           }) {
            return match
        }
        return loadedLLMs.first
    }

    /// Picks the saved chat model when listed; otherwise the first `/v1/models` entry (catalog fallback only).
    static func resolveChatModelID(current: String, available: [String]) -> String? {
        guard let first = available.first else { return nil }
        let chat = current.trimmingCharacters(in: .whitespacesAndNewlines)
        let needsDefault = chat.isEmpty || chat == "local-model"
        if needsDefault { return first }
        if available.contains(chat) { return nil }
        return first
    }

    /// Runs a connection check after chat failure and returns a user-facing message.
    func diagnoseChatFailure(_ error: Error) async -> String {
        let base = Self.actionableChatError(error, config: lmConfig)
        lmConnectionState = .connecting
        setActivity(.connecting)
        do {
            let models = try await lmClient.listModels()
            availableModels = models
            let nativeModels = (try? await lmClient.listNativeModels()) ?? []
            syncActiveChatModel(nativeModels: nativeModels, catalogModels: models)
            let loadedCount = nativeModels.filter { $0.type == "llm" && $0.isLoaded }.count
            let modelList = loadedCount > 0
                ? "Server OK · \(loadedCount) chat model\(loadedCount == 1 ? "" : "s") loaded."
                : (models.isEmpty
                    ? "Server reachable but no models loaded in LM Studio."
                    : "Server OK · load a chat model in LM Studio.")
            let chatListed = models.contains { $0.id == lmConfig.chatModel }
            let embedListed = models.contains { $0.id == lmConfig.resolvedEmbeddingModel }
            var hints: [String] = [modelList]
            if !chatListed, !lmConfig.chatModel.isEmpty {
                hints.append("Chat model “\(lmConfig.chatModelDisplay)” is not in the server list — pick a Chat model in Settings.")
            }
            if !embedListed, lmConfig.usesDedicatedEmbeddingModel {
                hints.append("Embedding model “\(lmConfig.resolvedEmbeddingModel)” is not loaded — set Embedding model or load it in LM Studio.")
            }
            setActivity(.error("\(base)\n\n\(hints.joined(separator: " "))"))
            lastChatError = activityState.statusMessage
            return lastChatError ?? base
        } catch {
            let connectionHint = Self.actionableConnectionError(error)
            lmStatus = "Error: \(error.localizedDescription)"
            lmConnectionState = .offline
            let combined = "\(base)\n\nConnection test failed: \(connectionHint)"
            setActivity(.error(combined))
            lastChatError = combined
            return combined
        }
    }

    /// Stream bytes prove reachability only — `/v1/models` confirms the configured chat model is loaded.
    func markChatStreamConnected() {
        if lmConnectionState == .offline || lmConnectionState == .notChecked {
            lmConnectionState = .connecting
        }
    }

    func confirmConnectionAfterStream() async {
        await checkConnection()
    }

    func markChatStreamFailed() {
        lmConnectionState = .offline
    }

    /// In-app pages plus all on-disk `.md` files under the vault root (Reor-style).
    static func indexEntries(including documents: [VaultDocument]) -> [VaultIndexEntry] {
        var byID: [UUID: VaultIndexEntry] = [:]
        byID.reserveCapacity(documents.count + 8)

        let vaultRoot = VaultLocationPreferences.resolvedVaultRootURL()
        let welcomeMarkdown = vaultRoot.appendingPathComponent("Welcome.md")
        let hasWelcomeMarkdown = FileManager.default.fileExists(atPath: welcomeMarkdown.path)

        for doc in documents {
            // Skip in-app welcome sample when `Welcome.md` is on disk — avoids duplicate index rows and pills.
            if hasWelcomeMarkdown, doc.id == VaultDocument.welcomeDocumentID {
                continue
            }
            byID[doc.id] = VaultIndexEntry(
                documentID: doc.id,
                title: doc.title,
                blocks: doc.rootBlocks,
                sourceFilename: nil,
                documentUpdatedAt: doc.updatedAt
            )
        }

        for file in VaultMarkdownCatalog.scan(vaultRoot: vaultRoot) {
            guard byID[file.documentID] == nil else { continue }
            guard let blocks = try? VaultMarkdownCatalog.loadBlocks(from: file) else { continue }
            byID[file.documentID] = VaultIndexEntry(
                documentID: file.documentID,
                title: file.title,
                blocks: blocks,
                sourceFilename: file.sourceFilename,
                documentUpdatedAt: file.modifiedAt
            )
        }
        return byID.values.sorted {
            $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    func reindex(documents: [VaultDocument]) async {
        indexingTask?.cancel()
        await indexer.cancel()
        isIndexing = true
        setActivity(.indexing)
        ingestionHealth.clearError()

        let payload = Self.indexEntries(including: documents)

        indexingTask = Task {
            defer {
                Task { @MainActor in
                    isIndexing = false
                    if case .indexing = activityState {
                        setActivity(.idle)
                    }
                }
            }
            do {
                try Task.checkCancellation()
                try await indexer.rebuildAll(entries: payload)
                let count = await vectorStore.chunkCount
                await MainActor.run {
                    indexedChunkCount = count
                    ingestionHealth.updateIndexedChunkCount(count)
                    lastPreparedVaultSignature = Self.vaultContentSignature(documents: documents)
                    applyIndexFingerprints(for: payload)
                }
            } catch is CancellationError {
                await MainActor.run { ingestionHealth.markCancelled() }
            } catch IngestionPipelineError.cancelled {
                await MainActor.run { ingestionHealth.markCancelled() }
            } catch {
                await MainActor.run {
                    ingestionHealth.recordError(error.localizedDescription)
                    lmStatus = "Index error: \(error.localizedDescription)"
                    setActivity(.error("Indexing failed: \(error.localizedDescription)"))
                }
            }
        }

        await indexingTask?.value
    }

    /// Re-ingests only vault entries whose content changed; removes index rows for deleted pages/markdown files.
    func reindexChangedDocuments(in documents: [VaultDocument]) async {
        let entries = Self.indexEntries(including: documents)
        if indexedDocumentFingerprints.isEmpty, indexedChunkCount > 0 {
            applyIndexFingerprints(for: entries)
        }

        let currentIDs = Set(entries.map(\.documentID))
        let staleIDs = indexedDocumentFingerprints.keys.filter { !currentIDs.contains($0) }
        let changed = entries.filter {
            indexedDocumentFingerprints[$0.documentID] != Self.entryFingerprint($0)
        }

        guard !staleIDs.isEmpty || !changed.isEmpty else {
            lastPreparedVaultSignature = Self.vaultContentSignature(documents: documents)
            return
        }

        indexingTask?.cancel()
        isIndexing = true
        ingestionHealth.clearError()

        indexingTask = Task {
            defer {
                Task { @MainActor in
                    isIndexing = false
                }
            }
            do {
                try Task.checkCancellation()
                for documentID in staleIDs {
                    try await indexer.remove(documentID: documentID)
                    indexedDocumentFingerprints.removeValue(forKey: documentID)
                }
                for entry in changed {
                    try await indexer.index(
                        documentID: entry.documentID,
                        title: entry.title,
                        blocks: entry.blocks,
                        sourceFilename: entry.sourceFilename,
                        documentUpdatedAt: entry.documentUpdatedAt
                    )
                    indexedDocumentFingerprints[entry.documentID] = Self.entryFingerprint(entry)
                }
                indexedChunkCount = await vectorStore.chunkCount
                ingestionHealth.updateIndexedChunkCount(indexedChunkCount)
                ingestionHealth.markCompleted(indexedChunks: indexedChunkCount)
                lastPreparedVaultSignature = Self.vaultContentSignature(documents: documents)
            } catch is CancellationError {
                ingestionHealth.markCancelled()
            } catch IngestionPipelineError.cancelled {
                ingestionHealth.markCancelled()
            } catch {
                ingestionHealth.recordError(error.localizedDescription)
                lmStatus = "Index error: \(error.localizedDescription)"
            }
        }

        await indexingTask?.value
    }

    func index(document: VaultDocument) async {
        let entry = VaultIndexEntry(
            documentID: document.id,
            title: document.title,
            blocks: document.rootBlocks,
            sourceFilename: nil,
            documentUpdatedAt: document.updatedAt
        )
        do {
            try await indexer.index(
                documentID: entry.documentID,
                title: entry.title,
                blocks: entry.blocks,
                sourceFilename: entry.sourceFilename,
                documentUpdatedAt: entry.documentUpdatedAt
            )
            indexedDocumentFingerprints[document.id] = Self.entryFingerprint(entry)
            indexedChunkCount = await vectorStore.chunkCount
            ingestionHealth.updateIndexedChunkCount(indexedChunkCount)
            ingestionHealth.markCompleted(indexedChunks: indexedChunkCount)
        } catch {
            ingestionHealth.recordError(error.localizedDescription)
            lmStatus = "Index error: \(error.localizedDescription)"
        }
    }

    /// Debounced incremental index after editor saves (avoids waiting for the 2s vault-wide reindex).
    func scheduleIndex(documentID: UUID, vaultStore: VaultStore) {
        documentIndexTasks[documentID]?.cancel()
        documentIndexTasks[documentID] = Task { [weak self, weak vaultStore] in
            try? await Task.sleep(nanoseconds: 900_000_000)
            guard !Task.isCancelled, let self, let vaultStore else { return }
            guard let document = vaultStore.documents.first(where: { $0.id == documentID }) else { return }
            await self.index(document: document)
        }
    }

    /// Ingest changed on-disk markdown through the FSEvents pipeline path.
    func ingestMarkdownFiles(at urls: [URL]) async {
        guard let pipeline = ingestionPipeline, !urls.isEmpty else { return }
        for url in urls {
            await pipeline.enqueueFilesystemChange(at: url)
        }
        do {
            try await pipeline.processPendingFilesystemEvents()
            indexedChunkCount = await vectorStore.chunkCount
            ingestionHealth.updateIndexedChunkCount(indexedChunkCount)
        } catch is CancellationError {
            ingestionHealth.markCancelled()
        } catch IngestionPipelineError.cancelled {
            ingestionHealth.markCancelled()
        } catch {
            ingestionHealth.recordError(error.localizedDescription)
        }
    }

    func startFilesystemIngestionWatch(roots: [URL] = []) async {
        var watchRoots = roots
        if watchRoots.isEmpty {
            watchRoots = [VaultLocationPreferences.resolvedVaultRootURL()]
        }
        await ingestionPipeline?.startFilesystemWatch(roots: watchRoots)
    }

    /// Single assistant bubble copy for chat failures (title + short reason).
    static func chatFailureBubble(_ error: Error, config: LMStudioConfig) -> String {
        "Response failed\n\(shortChatFailureReason(error, config: config))"
    }

    static func chatFailureBubble(message: String) -> String {
        let trimmed = message.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Response failed\nUnknown error." }
        if trimmed.lowercased().hasPrefix("response failed") { return trimmed }
        return "Response failed\n\(trimmed)"
    }

    static func shortChatFailureReason(_ error: Error, config: LMStudioConfig) -> String {
        let full = actionableChatError(error, config: config)
        if let first = full.split(separator: "\n").first {
            let line = String(first)
            if line.count <= 200 { return line }
            return String(line.prefix(197)) + "…"
        }
        return String(full.prefix(200))
    }

    static func actionableChatError(_ error: Error, config: LMStudioConfig) -> String {
        if let lm = error as? LMStudioError {
            switch lm {
            case .disabled:
                return "AI is disabled. Enable LM Studio and load a chat model."
            case .invalidURL:
                return "Invalid LM Studio URL (\(config.baseURL.absoluteString)). Use http://127.0.0.1:1234 in Settings."
            case .httpStatus(let code, let detail):
                if code == 404 {
                    let trimmed = config.chatModel.trimmingCharacters(in: .whitespacesAndNewlines)
                    if trimmed.isEmpty {
                        return "No chat model configured. Load a model in LM Studio, or pick a Chat model in Settings → AI."
                    }
                    return "Chat model not found. Load “\(trimmed)” in LM Studio or change Chat model in Settings."
                }
                if let detail, !detail.isEmpty {
                    return "LM Studio returned HTTP \(code): \(detail)"
                }
                return "LM Studio returned HTTP \(code). Check that the server is running and the chat model is loaded."
            case .emptyResponse:
                return "LM Studio returned an empty reply. Confirm the chat model is loaded and not out of memory."
            case .payloadTooLarge:
                return lm.errorDescription ?? "Prompt too large."
            case .embeddingsUnavailable:
                return "Embeddings unavailable — indexing uses a local fallback. Chat may still work if the chat model is loaded."
            case .decodeFailed:
                return "Could not parse LM Studio response. Update LM Studio or verify the OpenAI-compatible API is enabled."
            }
        }
        let description = error.localizedDescription
        if description.localizedCaseInsensitiveContains("could not connect")
            || description.localizedCaseInsensitiveContains("connection refused")
            || description.localizedCaseInsensitiveContains("network") {
            return "Cannot reach LM Studio at \(config.baseURL.absoluteString). Start the local server, then use Check connection in Settings."
        }
        return "\(description) Use Check connection in Settings if this persists."
    }

    static func actionableConnectionError(_ error: Error) -> String {
        if let lm = error as? LMStudioError {
            switch lm {
            case .invalidURL:
                return "Invalid base URL. Use http://127.0.0.1:1234"
            case .httpStatus(let code, let detail):
                if let detail, !detail.isEmpty {
                    return "HTTP \(code): \(detail)"
                }
                return "HTTP \(code) from LM Studio"
            default:
                return lm.errorDescription ?? "Connection failed"
            }
        }
        return "Cannot reach LM Studio — start the server on port 1234 and try again."
    }
}
