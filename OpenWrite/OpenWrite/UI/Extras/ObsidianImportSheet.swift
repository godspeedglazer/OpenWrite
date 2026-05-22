import SwiftUI
import UniformTypeIdentifiers

struct ObsidianImportSheet: View {
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var aiServices: OpenWriteAIServices

    let onDismiss: () -> Void

    @State private var isImporting = false
    @State private var resultMessage: String?
    @State private var showFolderPicker = false

    var body: some View {
        OWSettingsSheet(
            title: "Import Obsidian folder",
            dismissButtonTitle: "Close",
            dismissButtonUsesSecondaryStyle: true,
            onDone: onDismiss
        ) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing4) {
                Text("Copies `.md` files into your OpenWrite notes folder (skips `.obsidian`). Wikilinks `[[Page|Alias]]` normalize to `[[Page]]`; YAML frontmatter is stripped.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)

                Text("Notes folder: \(VaultLocationPreferences.resolvedVaultRootURL().path)")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                    .lineLimit(2)

                Button(isImporting ? "Importing…" : "Choose Obsidian vault folder…") {
                    showFolderPicker = true
                }
                .buttonStyle(.borderedProminent)
                .disabled(isImporting)

                if isImporting {
                    ProgressView()
                }

                if let resultMessage {
                    Text(resultMessage)
                        .font(DesignTokens.Typography.body)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, DesignTokens.Spacing.spacing4)
            .padding(.vertical, DesignTokens.Spacing.spacing3)
        }
        .frame(minWidth: 440)
        .fileImporter(
            isPresented: $showFolderPicker,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { outcome in
            Task { await handleImport(outcome) }
        }
    }

    private func handleImport(_ outcome: Result<[URL], Error>) async {
        await MainActor.run { isImporting = true }
        defer { Task { @MainActor in isImporting = false } }

        switch outcome {
        case .failure(let error):
            await MainActor.run { resultMessage = error.localizedDescription }
        case .success(let urls):
            guard let url = urls.first else { return }
            let accessed = url.startAccessingSecurityScopedResource()
            defer { if accessed { url.stopAccessingSecurityScopedResource() } }
            do {
                let notesRoot = VaultLocationPreferences.resolvedVaultRootURL()
                let result = try ObsidianVaultImporter.importFolder(from: url, into: notesRoot)
                await aiServices.ingestMarkdownFiles(
                    at: result.relativePaths.map { notesRoot.appendingPathComponent($0) }
                )
                await aiServices.reindex(documents: vaultStore.documentsInActiveVault)
                await MainActor.run {
                    resultMessage = "Imported \(result.copiedCount) file(s); skipped \(result.skippedCount) existing."
                    vaultStore.syncCanonicalWelcomeFromDisk()
                }
            } catch {
                await MainActor.run { resultMessage = error.localizedDescription }
            }
        }
    }
}
