// Anytype / Logseq-inspired workbench shell (clean-room SwiftUI).
// Sidebar density patterns studied from anytype-ts-develop; outliner rail ideas from logseq-master (AGPL).
// AI posture from reor-main (AGPL) — compact assist, not 50% split. See docs/ProductDirection.md.
// Leading navigation: OWNavigationRail (fixed width) — not NavigationSplitView sidebar List chrome.

import SwiftUI

struct AnytypeShellView: View {
    @Environment(\.openWritePalette) private var palette
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var pastWrites: InMemoryPastWritesService
    @ObservedObject var workbench: WorkbenchState
    let backlinkIndex: BacklinkIndex

    @Binding var showNewPageSheet: Bool
    @Binding var showAISettings: Bool
    @Binding var showCreateDatabaseSheet: Bool

    @State private var searchQuery: String = ""

    var body: some View {
        HStack(spacing: 0) {
            if workbench.sidebarVisible {
                OWNavigationRail(
                    workbench: workbench,
                    searchQuery: $searchQuery,
                    showNewPageSheet: $showNewPageSheet,
                    showAISettings: $showAISettings,
                    showCreateDatabaseSheet: $showCreateDatabaseSheet
                )
                .transition(.move(edge: .leading).combined(with: .opacity))
            }

            centerWorkbench
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(DesignTokens.Motion.animationStandard, value: workbench.sidebarVisible)
        .background(palette.background)
        .onChange(of: vaultStore.databases.map(\.id)) { _, databaseIDs in
            if case .database(let active) = workbench.centerTab,
               !databaseIDs.contains(active.id) {
                workbench.showEditor()
            }
        }
    }

    // MARK: - Center workbench

    private var centerWorkbench: some View {
        HStack(spacing: 0) {
            centerEditorColumn
                .frame(
                    minWidth: DesignTokens.Layout.editorMinWidth,
                    maxWidth: .infinity,
                    maxHeight: .infinity
                )
                .layoutPriority(1)

            if workbench.aiAssistExpanded {
                Rectangle()
                    .fill(DesignTokens.Color.borderSubtle)
                    .frame(width: DesignTokens.Layout.borderWidth)
                    .layoutPriority(0)

                AIAssistStripView(workbench: workbench, pastWrites: pastWrites) {
                    withAnimation(DesignTokens.Motion.animationStandard) {
                        workbench.aiAssistExpanded = false
                    }
                }
                .frame(
                    minWidth: DesignTokens.Layout.assistStripMinWidth,
                    maxWidth: DesignTokens.Layout.assistStripMaxWidth
                )
                .layoutPriority(0)
                .transition(.move(edge: .trailing).combined(with: .opacity))
            }
        }
        .animation(DesignTokens.Motion.animationStandard, value: workbench.aiAssistExpanded)
        .padding(DesignTokens.Layout.centerCardOuterPadding)
        .background(palette.workbenchChrome)
    }

    private var centerEditorColumn: some View {
        VStack(spacing: 0) {
            centerPageCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !workbench.aiAssistExpanded {
                AIAssistBottomBar(workbench: workbench) {
                    withAnimation(DesignTokens.Motion.animationStandard) {
                        workbench.aiAssistExpanded = true
                    }
                }
            }
        }
    }

    private var centerTabBarItems: [CenterWorkbenchTab] {
        var items: [CenterWorkbenchTab] = [.editor, .graph]
        if let database = vaultStore.selectedDatabase {
            items.append(.database(database))
        } else if case .database(let database) = workbench.centerTab {
            items.append(.database(database))
        }
        return items
    }

    private var centerTabBar: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            ForEach(centerTabBarItems) { tab in
                Button {
                    withAnimation(DesignTokens.Motion.animationStandard) {
                        switch tab {
                        case .editor:
                            workbench.showEditor()
                        case .graph:
                            workbench.showGraph()
                        case .database(let database):
                            vaultStore.selectedDatabaseID = database.id
                            vaultStore.selectedDocumentID = nil
                            workbench.showDatabase(database)
                        }
                    }
                } label: {
                    Text(tab.title)
                        .font(OWTypography.captionEmphasis)
                        .foregroundStyle(
                            isCenterTabSelected(tab)
                                ? DesignTokens.Color.textPrimary
                                : DesignTokens.Color.textTertiary
                        )
                        .padding(.horizontal, DesignTokens.Spacing.spacing2)
                        .padding(.vertical, DesignTokens.Spacing.spacing1)
                        .background(
                            isCenterTabSelected(tab)
                                ? DesignTokens.Color.surface
                                : Color.clear,
                            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                        )
                }
                .buttonStyle(.plain)
            }
            Spacer()
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .padding(.top, DesignTokens.Spacing.spacing1)
        .padding(.bottom, DesignTokens.Spacing.spacing1)
        .background(palette.editorCanvas)
    }

    private func isCenterTabSelected(_ tab: CenterWorkbenchTab) -> Bool {
        switch (workbench.centerTab, tab) {
        case (.editor, .editor), (.graph, .graph):
            return true
        case (.database(let active), .database(let candidate)):
            return active.id == candidate.id
        default:
            return false
        }
    }

    @ViewBuilder
    private var centerPageCard: some View {
        OWRoundedRect(style: .editorPanel, padding: 0) {
            VStack(spacing: 0) {
                centerTabBar
                Group {
                    switch workbench.centerTab {
                    case .editor:
                        editorCenter
                    case .database(let database):
                        databaseCenter(database)
                    case .graph:
                        GraphView(
                            documents: vaultStore.documents,
                            backlinkIndex: backlinkIndex,
                            selectedDocumentID: vaultStore.selectedDocumentID,
                            onSelectDocument: { documentID in
                                vaultStore.selectedDocumentID = documentID
                                withAnimation(DesignTokens.Motion.animationStandard) {
                                    workbench.showEditor()
                                }
                            }
                        )
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous))
    }

    @ViewBuilder
    private func databaseCenter(_ database: OWDatabase) -> some View {
        let resolved = vaultStore.databases.first { $0.id == database.id } ?? database
        if vaultStore.databases.contains(where: { $0.id == database.id }) {
            DatabaseTableView(database: resolved)
        } else {
            OWPageHero(
                title: "Select a database",
                subtitle: "Pick a database from the sidebar or create one with +.",
                icon: .collection,
                style: .emptyState,
                compact: true
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private var editorCenter: some View {
        if let doc = vaultStore.selectedDocument {
            EditorView(documentID: doc.id)
        } else {
            emptyEditorState
        }
    }

    private var emptyEditorState: some View {
        VStack(spacing: DesignTokens.Spacing.spacing4) {
            OWPageHero(
                title: "No page open",
                subtitle: "Choose a note from the vault or create a new object.",
                icon: .editCompose,
                style: .emptyState,
                compact: true
            )

            Button {
                showNewPageSheet = true
            } label: {
                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    OWUnicodeIconView(icon: .plus, size: 16, color: DesignTokens.Color.accent)
                    Text("+ New object")
                        .font(OWTypography.bodyEmphasis)
                }
                .padding(.horizontal, DesignTokens.Spacing.spacing4)
                .padding(.vertical, DesignTokens.Spacing.spacing2)
                .background(DesignTokens.Color.selectionPill.opacity(0.9), in: Capsule())
            }
            .buttonStyle(.plain)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
