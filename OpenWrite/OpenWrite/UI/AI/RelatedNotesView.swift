import SwiftUI
import Combine

@MainActor
final class RelatedNotesModel: ObservableObject {
    @Published var hits: [RetrievalHit] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    private var loadTask: Task<Void, Never>?
    private var debounceTask: Task<Void, Never>?

    func scheduleLoad(document: VaultDocument?, services: OpenWriteAIServices) {
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(nanoseconds: UInt64(AISafetyLimits.searchDebounceSeconds * 1_000_000_000))
            guard !Task.isCancelled else { return }
            await load(document: document, services: services)
        }
    }

    func load(document: VaultDocument?, services: OpenWriteAIServices) async {
        loadTask?.cancel()
        guard let document else {
            hits = []
            errorMessage = nil
            return
        }

        loadTask = Task {
            isLoading = true
            errorMessage = nil
            defer { isLoading = false }

            do {
                let related = try await services.retrieval.related(
                    to: document.id,
                    limit: AISafetyLimits.rerankCandidateCount
                )
                guard !Task.isCancelled else { return }
                hits = related
            } catch {
                guard !Task.isCancelled else { return }
                hits = []
                errorMessage = error.localizedDescription
            }
        }
    }

    func open(hit: RetrievalHit, vaultStore: VaultStore) {
        vaultStore.selectedDocumentID = hit.documentID
    }
}

struct RelatedNotesView: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @StateObject private var model = RelatedNotesModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 260)
        .onChange(of: vaultStore.selectedDocumentID) { _, _ in
            model.scheduleLoad(document: vaultStore.selectedDocument, services: aiServices)
        }
        .onAppear {
            model.scheduleLoad(document: vaultStore.selectedDocument, services: aiServices)
        }
        .onChange(of: aiServices.indexedChunkCount) { _, _ in
            model.scheduleLoad(document: vaultStore.selectedDocument, services: aiServices)
        }
    }

    private var header: some View {
        HStack {
            Text("Related notes")
                .font(.headline)
            Spacer()
            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = model.errorMessage {
            ContentUnavailableView(
                "Could not load",
                systemImage: "exclamationmark.triangle",
                description: Text(errorMessage)
            )
            .padding()
        } else if model.hits.isEmpty {
            ContentUnavailableView(
                vaultStore.selectedDocument == nil ? "No note selected" : "No related notes yet",
                systemImage: "link",
                description: Text(
                    vaultStore.selectedDocument == nil
                        ? "Select a note to see semantic neighbors."
                        : "Index the vault or add more notes for better matches."
                )
            )
            .padding()
        } else {
            List(model.hits) { hit in
                Button {
                    model.open(hit: hit, vaultStore: vaultStore)
                } label: {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack {
                            Text(hit.documentTitle)
                                .font(.body.weight(.medium))
                            Spacer()
                            Text(String(format: "%.0f%%", hit.score * 100))
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                        Text(hit.snippet)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(3)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
            .listStyle(.plain)
        }
    }
}
