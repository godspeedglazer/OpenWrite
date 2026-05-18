import Foundation
import Combine

@MainActor
final class OpenWriteAIServices: ObservableObject {
    @Published var lmConfig: LMStudioConfig = .default
    @Published var lmStatus: String = "Not checked"
    @Published var availableModels: [LMStudioModel] = []
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

    private var ingestionPipeline: IngestionPipeline?
    private var indexingTask: Task<Void, Never>?
    private var cancellables = Set<AnyCancellable>()
    /// Vault content signature reflected in the last successful `prepareVaultIndex` / `reindex`.
    private(set) var lastPreparedVaultSignature: Int?

    /// True after a successful connection check (`lmStatus` begins with "Connected").
    var isLMStudioConnected: Bool {
        lmStatus.hasPrefix("Connected")
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
            return
        }
        guard Self.hasIndexableContent(documents: documents) else { return }
        await reindex(documents: documents)
        lastPreparedVaultSignature = signature
    }

    static func vaultContentSignature(documents: [VaultDocument]) -> Int {
        var hasher = Hasher()
        for entry in indexEntries(including: documents) {
            hasher.combine(entry.documentID)
            hasher.combine(entry.title)
            hasher.combine(entry.blocks.count)
            hasher.combine(entry.sourceFilename ?? "")
        }
        return hasher.finalize()
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

    func checkConnection() async {
        setActivity(.connecting)
        lmStatus = "Checking…"
        do {
            let models = try await lmClient.listModels()
            availableModels = models
            if !models.isEmpty {
                let chat = lmConfig.chatModel.trimmingCharacters(in: .whitespacesAndNewlines)
                let needsDefault = chat.isEmpty || chat == "local-model"
                let preferred = models.first { $0.id.localizedCaseInsensitiveContains("gemma") }
                if needsDefault {
                    lmConfig.chatModel = preferred?.id ?? models[0].id
                    LMStudioConfigPersistence.save(lmConfig)
                    rebuildPipeline()
                } else if !models.contains(where: { $0.id == lmConfig.chatModel }),
                          let preferred {
                    lmConfig.chatModel = preferred.id
                    LMStudioConfigPersistence.save(lmConfig)
                    rebuildPipeline()
                }
            }
            lmStatus = models.isEmpty ? "Connected (no models)" : "Connected · \(models.count) models"
            setActivity(.idle)
        } catch {
            availableModels = []
            lmStatus = "Error: \(error.localizedDescription)"
            setActivity(.error(Self.actionableConnectionError(error)))
        }
    }

    /// Runs a connection check after chat failure and returns a user-facing message.
    func diagnoseChatFailure(_ error: Error) async -> String {
        let base = Self.actionableChatError(error, config: lmConfig)
        setActivity(.connecting)
        do {
            let models = try await lmClient.listModels()
            availableModels = models
            let modelList = models.isEmpty
                ? "Server reachable but no models loaded in LM Studio."
                : "Server OK · \(models.count) model\(models.count == 1 ? "" : "s") loaded."
            let chatListed = models.contains { $0.id == lmConfig.chatModel }
            let embedListed = models.contains { $0.id == lmConfig.resolvedEmbeddingModel }
            var hints: [String] = [modelList]
            if !chatListed, !lmConfig.chatModel.isEmpty {
                hints.append("Chat model “\(lmConfig.chatModel)” is not in the server list — pick a Chat model in Settings.")
            }
            if !embedListed, lmConfig.usesDedicatedEmbeddingModel {
                hints.append("Embedding model “\(lmConfig.resolvedEmbeddingModel)” is not loaded — set Embedding model or load it in LM Studio.")
            }
            lmStatus = models.isEmpty ? "Connected (no models)" : "Connected · \(models.count) models"
            setActivity(.error("\(base)\n\n\(hints.joined(separator: " "))"))
            lastChatError = activityState.statusMessage
            return lastChatError ?? base
        } catch {
            let connectionHint = Self.actionableConnectionError(error)
            lmStatus = "Error: \(error.localizedDescription)"
            let combined = "\(base)\n\nConnection test failed: \(connectionHint)"
            setActivity(.error(combined))
            lastChatError = combined
            return combined
        }
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
                sourceFilename: nil
            )
        }

        for file in VaultMarkdownCatalog.scan(vaultRoot: vaultRoot) {
            guard byID[file.documentID] == nil else { continue }
            guard let blocks = try? VaultMarkdownCatalog.loadBlocks(from: file) else { continue }
            byID[file.documentID] = VaultIndexEntry(
                documentID: file.documentID,
                title: file.title,
                blocks: blocks,
                sourceFilename: file.sourceFilename
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

    func index(document: VaultDocument) async {
        do {
            try await indexer.index(
                documentID: document.id,
                title: document.title,
                blocks: document.rootBlocks,
                sourceFilename: nil
            )
            indexedChunkCount = await vectorStore.chunkCount
            ingestionHealth.updateIndexedChunkCount(indexedChunkCount)
        } catch {
            ingestionHealth.recordError(error.localizedDescription)
            lmStatus = "Index error: \(error.localizedDescription)"
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
                    return "Chat model not found. Load “\(config.chatModelDisplay)” in LM Studio or change Chat model in Settings."
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
