import Foundation
import Combine

@MainActor
final class OpenWriteAIServices: ObservableObject {
    @Published var lmConfig: LMStudioConfig = .default
    @Published var lmStatus: String = "Not checked"
    @Published var availableModels: [LMStudioModel] = []
    @Published var isIndexing = false
    @Published var indexedChunkCount = 0

    let vectorStore = InMemoryVectorStore()
    private(set) var lmClient: LMStudioClient
    private(set) var embeddings: EmbeddingService
    private(set) var indexer: IndexerService
    private(set) var retrieval: RetrievalService
    private(set) var rag: RAGService

    init() {
        lmClient = LMStudioClient(config: .default)
        embeddings = LocalHashEmbeddingService()
        indexer = NoOpIndexerService()
        retrieval = NoOpRetrievalService()
        rag = PlaceholderRAGService(retrieval: NoOpRetrievalService())
        rebuildPipeline()
    }

    func applyConfig(_ config: LMStudioConfig) {
        lmConfig = config
        rebuildPipeline()
    }

    func rebuildPipeline() {
        lmClient = LMStudioClient(config: lmConfig)
        embeddings = LMStudioEmbeddingService(
            client: lmClient,
            fallback: LocalHashEmbeddingService()
        )
        indexer = InMemoryIndexerService(vectorStore: vectorStore, embeddings: embeddings)
        retrieval = HybridRetrievalService(vectorStore: vectorStore, embeddings: embeddings)
        rag = LiveRAGService(retrieval: retrieval, client: lmClient)
    }

    func checkConnection() async {
        lmStatus = "Checking…"
        do {
            let models = try await lmClient.listModels()
            availableModels = models
            if !models.isEmpty, lmConfig.chatModel == "local-model" || lmConfig.chatModel.isEmpty {
                lmConfig.chatModel = models[0].id
                rebuildPipeline()
            }
            lmStatus = models.isEmpty ? "Connected (no models)" : "Connected · \(models.count) models"
        } catch {
            availableModels = []
            lmStatus = "Error: \(error.localizedDescription)"
        }
    }

    func reindex(documents: [VaultDocument]) async {
        isIndexing = true
        defer { isIndexing = false }
        let payload = documents.map { (id: $0.id, title: $0.title, blocks: $0.rootBlocks) }
        do {
            try await indexer.rebuildAll(documents: payload)
            indexedChunkCount = await vectorStore.chunkCount
        } catch {
            lmStatus = "Index error: \(error.localizedDescription)"
        }
    }

    func index(document: VaultDocument) async {
        do {
            try await indexer.index(
                documentID: document.id,
                title: document.title,
                blocks: document.rootBlocks
            )
            indexedChunkCount = await vectorStore.chunkCount
        } catch {
            lmStatus = "Index error: \(error.localizedDescription)"
        }
    }
}
