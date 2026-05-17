// Anytype / Logseq-inspired workbench shell (clean-room SwiftUI).
// Sidebar density patterns studied from anytype-ts-develop; outliner rail ideas from logseq-master (AGPL).
// AI posture from reor-main (AGPL) — compact assist, not 50% split. See docs/ProductDirection.md.

import SwiftUI

struct AnytypeShellView: View {
    @Environment(ThemeManager.self) private var themeManager
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var aiServices: OpenWriteAIServices
    @EnvironmentObject private var pastWrites: InMemoryPastWritesService
    @ObservedObject var workbench: WorkbenchState
    let backlinkIndex: BacklinkIndex

    @Binding var showNewPageSheet: Bool
    @Binding var showAISettings: Bool
    @Binding var showCreateDatabaseSheet: Bool

    @State private var searchQuery: String = ""

    private var filteredDocuments: [VaultDocument] {
        var docs = vaultStore.documents
        if let filter = workbench.vaultTypeFilter {
            docs = docs.filter { $0.pageType == filter }
        }
        let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { return docs }
        return docs.filter {
            $0.displayTitle.localizedCaseInsensitiveContains(q)
                || $0.plainText.localizedCaseInsensitiveContains(q)
        }
    }

    var body: some View {
        NavigationSplitView {
            leftSidebar
        } detail: {
            centerWorkbench
        }
        .navigationSplitViewColumnWidth(
            min: DesignTokens.Layout.sidebarMinWidth,
            ideal: DesignTokens.Layout.sidebarPreferredWidth,
            max: DesignTokens.Layout.sidebarMaxWidth
        )
        .background(DesignTokens.Color.background)
    }

    // MARK: - Left sidebar

    private var leftSidebar: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                    spaceHeader
                    searchStub
                    objectsSection
                    DatabaseListView(
                        workbench: workbench,
                        showCreateDatabaseSheet: $showCreateDatabaseSheet
                    )
                    vaultSection
                    pinnedStub
                }
                .padding(DesignTokens.Spacing.sidebarPadding)
            }

            sidebarBottomActions
        }
        .background(DesignTokens.Color.sidebarBackground)
    }

    private var spaceHeader: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            OWIconView(icon: .lockShield, size: 18, color: DesignTokens.Color.accent)
            VStack(alignment: .leading, spacing: 2) {
                Text("OpenWrite")
                    .font(DesignTokens.Typography.bodyEmphasis)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                Text("Local vault")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            }
            Spacer()
            Button {
                showNewPageSheet = true
            } label: {
                OWIconView(icon: .plus, size: 16, color: DesignTokens.Color.accent)
            }
            .buttonStyle(.plain)
            .foregroundStyle(DesignTokens.Color.accent)
            .help("New page")
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing1)
    }

    private var searchStub: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            OWIconView(icon: .search, size: 14, color: DesignTokens.Color.textTertiary)
            TextField("Search vault…", text: $searchQuery)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.sidebarItem)
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .padding(.vertical, DesignTokens.Spacing.spacing1)
        .background(DesignTokens.Color.selectionPill.opacity(0.85), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var objectsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            sidebarSectionLabel("Objects")

            OWRoundedRect(style: .sidebarCard, padding: DesignTokens.Spacing.spacing2) {
                VStack(spacing: DesignTokens.Spacing.spacing1) {
                    ForEach(objectNavTypes, id: \.self) { type in
                        OWSidebarRow(
                            title: type.displayName,
                            pageType: type,
                            isSelected: workbench.vaultTypeFilter == type
                        ) {
                            if workbench.vaultTypeFilter == type {
                                workbench.vaultTypeFilter = nil
                            } else {
                                workbench.vaultTypeFilter = type
                            }
                        }
                    }

                    OWSidebarRow(
                        title: SidebarSection.graph.title,
                        subtitle: "Vault topology",
                        showsGraphGlyph: true,
                        isSelected: workbench.centerTab == .graph
                    ) {
                        withAnimation(DesignTokens.Motion.animationStandard) {
                            workbench.showGraph()
                        }
                    }
                }
            }
        }
    }

    /// Object types shown as Anytype-style colored nav rows.
    private var objectNavTypes: [PageType] {
        [.note, .task, .journal, .project, .reference, .collection]
    }

    private var vaultSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            HStack {
                sidebarSectionLabel("Vault")
                Spacer()
                if workbench.vaultTypeFilter != nil {
                    Button("Clear filter") {
                        workbench.vaultTypeFilter = nil
                    }
                    .font(DesignTokens.Typography.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignTokens.Color.accent)
                }
            }

            if filteredDocuments.isEmpty {
                Text("No pages")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .padding(.horizontal, DesignTokens.Spacing.spacing2)
            } else {
                ForEach(filteredDocuments) { doc in
                    OWSidebarRow(
                        title: doc.displayTitle,
                        subtitle: doc.pageType.displayName,
                        pageType: doc.pageType,
                        isSelected: vaultStore.selectedDocumentID == doc.id
                    ) {
                        vaultStore.selectedDocumentID = doc.id
                        vaultStore.selectedDatabaseID = nil
                        workbench.showEditor()
                    }
                }
            }
        }
    }

    private var pinnedStub: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            sidebarSectionLabel("Pinned")
            OWRoundedRect(style: .sidebarCard, padding: DesignTokens.Spacing.spacing2) {
                Text("Pin pages here soon.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            }
        }
    }

    private func sidebarSectionLabel(_ title: String) -> some View {
        Text(title.uppercased())
            .font(DesignTokens.Typography.sidebarSection)
            .foregroundStyle(DesignTokens.Color.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.spacing2)
    }

    private var sidebarBottomActions: some View {
        VStack(spacing: DesignTokens.Spacing.spacing2) {
            ingestionSidebarFooter

            HStack(spacing: DesignTokens.Spacing.spacing3) {
                sidebarBottomButton(icon: .settings, help: "Settings") {
                    showAISettings = true
                }

                sidebarBottomButton(
                    icon: .sparkles,
                    help: "Cycle theme (\(themeManager.selectedTheme.displayName))"
                ) {
                    themeManager.selectNext()
                }

            Spacer()

            Circle()
                .fill(aiStatusColor)
                .frame(width: 8, height: 8)
                .padding(DesignTokens.Spacing.spacing3)
                .help(aiServices.activityState.shortLabel)
            }
        }
        .padding(DesignTokens.Spacing.sidebarPadding)
        .background(
            LinearGradient(
                colors: [
                    DesignTokens.Color.sidebarBackground.opacity(0),
                    DesignTokens.Color.sidebarBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var ingestionSidebarFooter: some View {
        let health = aiServices.ingestionHealth.health
        return VStack(alignment: .leading, spacing: 4) {
            HStack(spacing: DesignTokens.Spacing.spacing2) {
                Text("Ingestion")
                    .font(DesignTokens.Typography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                Spacer()
                Text(health.statusLabel)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            }

            if health.isActive || aiServices.isIndexing {
                if let summary = health.progressSummary {
                    Text(summary)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }
                ProgressView(value: health.progressFraction)
                    .controlSize(.small)
            } else {
                Text("\(aiServices.indexedChunkCount) chunks indexed")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            }

            if let error = health.lastError, !error.isEmpty {
                Text(error)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.danger)
                    .lineLimit(2)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Vault ingestion \(health.statusLabel)")
    }

    private func sidebarBottomButton(icon: OWIcon, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            OWIconView(icon: icon, size: 16, color: DesignTokens.Color.textSecondary)
                .frame(
                    width: DesignTokens.Layout.sidebarBottomButtonSize,
                    height: DesignTokens.Layout.sidebarBottomButtonSize
                )
                .background(DesignTokens.Color.selectionPill.opacity(0.9), in: Circle())
                .overlay {
                    Circle()
                        .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .help(help)
    }

    private var aiStatusColor: Color {
        switch aiServices.activityState {
        case .idle:
            return DesignTokens.Color.success
        case .error:
            return DesignTokens.Color.danger
        default:
            return DesignTokens.Color.accent
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
        .background(DesignTokens.Color.workbenchChrome)
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
                        .font(DesignTokens.Typography.captionEmphasis)
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
        .padding(.horizontal, DesignTokens.Spacing.spacing3)
        .padding(.top, DesignTokens.Spacing.spacing2)
        .padding(.bottom, DesignTokens.Spacing.spacing1)
        .background(DesignTokens.Color.editorCanvas)
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
                    OWIconView(icon: .plus, size: 16, color: DesignTokens.Color.accent)
                    Text("+ New object")
                        .font(DesignTokens.Typography.bodyEmphasis)
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
