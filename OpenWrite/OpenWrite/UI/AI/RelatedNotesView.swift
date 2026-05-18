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
    @EnvironmentObject private var workbench: WorkbenchState
    @StateObject private var model = RelatedNotesModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            Divider()
            content
        }
        .frame(minWidth: 260)
        .background(DesignTokens.Color.background)
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
                .font(OWTypography.panelTitle)
                .foregroundStyle(DesignTokens.Color.textPrimary)
            Spacer()
            if model.isLoading {
                ProgressView()
                    .controlSize(.small)
            }
        }
        .padding(DesignTokens.Spacing.assistStripContentPadding)
    }

    @ViewBuilder
    private var content: some View {
        if let errorMessage = model.errorMessage {
            OWEmptyState(
                title: "Could not load",
                icon: .warning,
                description: Text(errorMessage)
            )
            .padding(DesignTokens.Spacing.assistStripContentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else if model.hits.isEmpty {
            OWEmptyState(
                title: vaultStore.selectedDocument == nil ? "No note selected" : "No related notes yet",
                icon: .link,
                description: Text(
                    vaultStore.selectedDocument == nil
                        ? "Select a note to see semantic neighbors."
                        : "Index the vault or add more notes for better matches."
                )
            )
            .padding(DesignTokens.Spacing.assistStripContentPadding)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                    ForEach(model.hits) { hit in
                        relatedNoteCard(hit)
                    }
                }
                .padding(DesignTokens.Spacing.assistStripContentPadding)
            }
        }
    }

    private func relatedNoteCard(_ hit: RetrievalHit) -> some View {
        Button {
            workbench.aiAssistNavigation.openRelatedDetail(hit)
        } label: {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
                HStack(alignment: .firstTextBaseline) {
                    Text(hit.documentTitle)
                        .font(OWTypography.bodyEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: DesignTokens.Spacing.spacing2)
                    Text(String(format: "%.0f%%", hit.score * 100))
                        .font(OWTypography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }
                Text(hit.snippet)
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing2)
            .padding(.vertical, DesignTokens.Spacing.spacing3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                DesignTokens.Color.surfaceElevated,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderSubtle.opacity(0.65), lineWidth: DesignTokens.Layout.borderWidth)
            }
        }
        .buttonStyle(.plain)
    }
}
