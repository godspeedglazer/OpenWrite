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

    private var ingestionPipeline: IngestionPipeline?
    private var indexingTask: Task<Void, Never>?

    init() {
        lmClient = LMStudioClient(config: .default)
        embeddings = LocalHashEmbeddingService()
        indexer = NoOpIndexerService()
        retrieval = NoOpRetrievalService()
        rag = PlaceholderRAGService(retrieval: NoOpRetrievalService())
        vectorStore.attachHealth(ingestionHealth)
        rebuildPipeline()
        Task {
            await vectorStore.loadFromDiskIfPresent()
            let count = await vectorStore.chunkCount
            indexedChunkCount = count
            ingestionHealth.updateIndexedChunkCount(count)
        }
    }

    func applyConfig(_ config: LMStudioConfig) {
        lmConfig = config
        rebuildPipeline()
    }

    func updateChatModel(_ modelID: String) {
        lmConfig.chatModel = modelID
        rebuildPipeline()
    }

    func updateEmbeddingModel(_ modelID: String) {
        lmConfig.embeddingModel = modelID
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
            if !models.isEmpty, lmConfig.chatModel == "local-model" || lmConfig.chatModel.isEmpty {
                lmConfig.chatModel = models[0].id
                rebuildPipeline()
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

    func reindex(documents: [VaultDocument]) async {
        indexingTask?.cancel()
        await indexer.cancel()
        isIndexing = true
        setActivity(.indexing)
        ingestionHealth.clearError()

        let payload = documents.map { (id: $0.id, title: $0.title, blocks: $0.rootBlocks) }

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
                try await indexer.rebuildAll(documents: payload)
                let count = await vectorStore.chunkCount
                await MainActor.run {
                    indexedChunkCount = count
                    ingestionHealth.updateIndexedChunkCount(count)
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
                blocks: document.rootBlocks
            )
            indexedChunkCount = await vectorStore.chunkCount
            ingestionHealth.updateIndexedChunkCount(indexedChunkCount)
        } catch {
            ingestionHealth.recordError(error.localizedDescription)
            lmStatus = "Index error: \(error.localizedDescription)"
        }
    }

    func startFilesystemIngestionWatch() async {
        await ingestionPipeline?.startFilesystemWatch()
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
                return lm.localizedDescription ?? "Prompt too large."
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
                return lm.localizedDescription ?? "Connection failed"
            }
        }
        return "Cannot reach LM Studio — start the server on port 1234 and try again."
    }
}
