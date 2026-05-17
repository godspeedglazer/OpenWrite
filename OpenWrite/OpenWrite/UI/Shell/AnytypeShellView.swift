// Anytype / Logseq-inspired workbench shell (clean-room SwiftUI).
// Sidebar density patterns studied from anytype-ts-develop; outliner rail ideas from logseq-master (AGPL).
// AI posture from reor-main (AGPL) — compact assist, not 50% split. See docs/ProductDirection.md.
// Leading navigation: OWNavigationRail — custom rects, draggable width, filled shell title bar.

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
    @State private var navigationRailWidth: CGFloat = ShellChromePreferences.navigationRailWidth
    @State private var assistStripWidth: CGFloat = ShellChromePreferences.assistStripWidth

    var body: some View {
        VStack(spacing: 0) {
            OWShellTitleBar(
                tabs: centerTabBarItems,
                selectedTab: workbench.centerTab,
                onSelectTab: selectCenterTab
            )

            shellBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(DesignTokens.Motion.animationStandard, value: workbench.sidebarVisible)
        .animation(DesignTokens.Motion.animationStandard, value: workbench.aiAssistExpanded)
        .animation(DesignTokens.Motion.animationStandard, value: workbench.navigationRailCollapsed)
        .background(palette.background)
        .onChange(of: workbench.sidebarVisible) { _, _ in workbench.persistChromePreferences() }
        .onChange(of: workbench.aiAssistExpanded) { _, _ in workbench.persistChromePreferences() }
        .onChange(of: workbench.navigationRailCollapsed) { _, collapsed in
            workbench.persistChromePreferences()
            if collapsed {
                navigationRailWidth = DesignTokens.Layout.navigationRailCollapsedWidth
            } else {
                navigationRailWidth = ShellChromePreferences.navigationRailWidth
            }
        }
        .onAppear {
            if workbench.navigationRailCollapsed {
                navigationRailWidth = DesignTokens.Layout.navigationRailCollapsedWidth
            }
        }
        .onChange(of: vaultStore.databases.map(\.id)) { _, databaseIDs in
            if case .database(let active) = workbench.centerTab,
               !databaseIDs.contains(active.id) {
                workbench.showEditor()
            }
        }
    }

    private var shellBody: some View {
        GeometryReader { geometry in
            Group {
                if workbench.sidebarVisible {
                    OWResizableColumnSplit(
                        fixedWidth: $navigationRailWidth,
                        minWidth: navigationRailMinWidth,
                        maxWidth: navigationRailMaxWidth,
                        isResizable: !workbench.navigationRailCollapsed,
                        flexibleMinWidth: DesignTokens.Layout.editorMinWidth
                            + DesignTokens.Layout.centerCardOuterPadding * 2,
                        onCommitWidth: { ShellChromePreferences.navigationRailWidth = $0 }
                    ) {
                        navigationRailColumn
                            .transition(.move(edge: .leading).combined(with: .opacity))
                    } trailing: {
                        centerWorkbench
                    }
                } else {
                    centerWorkbench
                }
            }
            .frame(width: geometry.size.width, height: geometry.size.height, alignment: .leading)
        }
    }

    private var navigationRailMinWidth: CGFloat {
        workbench.navigationRailCollapsed
            ? DesignTokens.Layout.navigationRailCollapsedWidth
            : DesignTokens.Layout.sidebarMinWidth
    }

    private var navigationRailMaxWidth: CGFloat {
        workbench.navigationRailCollapsed
            ? DesignTokens.Layout.navigationRailCollapsedWidth
            : DesignTokens.Layout.sidebarMaxWidth
    }

    @ViewBuilder
    private var navigationRailColumn: some View {
        if workbench.navigationRailCollapsed {
            OWNavigationRailCollapsed(
                workbench: workbench,
                showNewPageSheet: $showNewPageSheet,
                showAISettings: $showAISettings,
                onExpand: {
                    withAnimation(DesignTokens.Motion.animationStandard) {
                        workbench.navigationRailCollapsed = false
                        navigationRailWidth = ShellChromePreferences.navigationRailWidth
                    }
                }
            )
        } else {
            OWNavigationRail(
                workbench: workbench,
                searchQuery: $searchQuery,
                showNewPageSheet: $showNewPageSheet,
                showAISettings: $showAISettings,
                showCreateDatabaseSheet: $showCreateDatabaseSheet,
                onCollapse: {
                    withAnimation(DesignTokens.Motion.animationStandard) {
                        ShellChromePreferences.navigationRailWidth = navigationRailWidth
                        workbench.navigationRailCollapsed = true
                        navigationRailWidth = DesignTokens.Layout.navigationRailCollapsedWidth
                    }
                }
            )
        }
    }

    // MARK: - Center workbench

    private var centerWorkbench: some View {
        GeometryReader { geometry in
            let centerWidth = geometry.size.width
            let editorMin = OWShellLayout.editorMinimum(forCenterWidth: centerWidth)

            Group {
                if workbench.aiAssistExpanded {
                    OWResizableColumnSplit(
                        fixedWidth: $assistStripWidth,
                        minWidth: DesignTokens.Layout.assistStripMinWidth,
                        maxWidth: DesignTokens.Layout.assistStripMaxWidth,
                        fixedColumn: .trailing,
                        flexibleMinWidth: editorMin,
                        onCommitWidth: { ShellChromePreferences.assistStripWidth = $0 }
                    ) {
                        centerEditorColumn
                            .frame(
                                minWidth: editorMin,
                                maxWidth: .infinity,
                                maxHeight: .infinity
                            )
                            .layoutPriority(1)
                    } trailing: {
                        AIAssistStripView(workbench: workbench, pastWrites: pastWrites) {
                            withAnimation(DesignTokens.Motion.animationStandard) {
                                workbench.aiAssistExpanded = false
                                workbench.persistChromePreferences()
                            }
                        }
                        .frame(maxHeight: .infinity)
                        .layoutPriority(0)
                        .transition(.move(edge: .trailing).combined(with: .opacity))
                    }
                } else {
                    centerEditorColumn
                        .frame(
                            minWidth: editorMin,
                            maxWidth: .infinity,
                            maxHeight: .infinity
                        )
                }
            }
            .frame(width: centerWidth, height: geometry.size.height, alignment: .leading)
            .onAppear {
                reconcileCenterWorkbenchLayout(centerWidth: centerWidth)
            }
            .onChange(of: centerWidth) { _, newWidth in
                reconcileCenterWorkbenchLayout(centerWidth: newWidth)
            }
            .onChange(of: workbench.aiAssistExpanded) { _, expanded in
                if expanded {
                    reconcileCenterWorkbenchLayout(centerWidth: centerWidth)
                }
            }
        }
        .padding(DesignTokens.Layout.centerCardOuterPadding)
        .background(palette.workbenchChrome)
    }

    private func reconcileCenterWorkbenchLayout(centerWidth: CGFloat) {
        guard workbench.aiAssistExpanded else { return }

        if !OWShellLayout.canFitAssistStrip(centerWidth: centerWidth) {
            withAnimation(DesignTokens.Motion.animationStandard) {
                workbench.aiAssistExpanded = false
                workbench.persistChromePreferences()
            }
            return
        }

        let resolvedAssist = OWShellLayout.maxAssistWidth(
            centerWidth: centerWidth,
            preferredAssistWidth: assistStripWidth
        )
        if abs(assistStripWidth - resolvedAssist) > 0.5 {
            assistStripWidth = resolvedAssist
            ShellChromePreferences.assistStripWidth = resolvedAssist
        }
    }

    private var centerEditorColumn: some View {
        VStack(spacing: 0) {
            centerPageCard
                .frame(maxWidth: .infinity, maxHeight: .infinity)

            if !workbench.aiAssistExpanded {
                AIAssistBottomBar(workbench: workbench) {
                    withAnimation(DesignTokens.Motion.animationStandard) {
                        workbench.aiAssistExpanded = true
                        workbench.persistChromePreferences()
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

    private func selectCenterTab(_ tab: CenterWorkbenchTab) {
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
    }

    @ViewBuilder
    private var centerPageCard: some View {
        OWRoundedRect(style: .editorPanel, padding: 0) {
            Group {
                switch workbench.centerTab {
                case .editor:
                    editorCenter
                case .database(let database):
                    databaseCenter(database)
                case .graph:
                    GraphView(
                        documents: vaultStore.documentsInActiveVault,
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
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing4) {
                OWPageHero(
                    title: "No page open",
                    subtitle: "Choose a note from the vault or create a new object.",
                    icon: .editCompose,
                    style: .emptyState,
                    compact: true
                )
                .frame(maxWidth: .infinity)

                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    Button {
                        showNewPageSheet = true
                    } label: {
                        HStack(spacing: DesignTokens.Spacing.spacing2) {
                            OWUnicodeIconView(icon: .plus, size: 16, color: DesignTokens.Color.accent)
                            Text("New object")
                                .font(OWTypography.bodyEmphasis)
                        }
                        .padding(.horizontal, DesignTokens.Spacing.spacing4)
                        .padding(.vertical, DesignTokens.Spacing.spacing2)
                        .background(
                            DesignTokens.Color.selectionPill.opacity(0.9),
                            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                        )
                    }
                    .buttonStyle(.plain)

                    if let welcome = vaultStore.documents.first(where: { $0.id == VaultDocument.welcomeDocumentID }) {
                        Button {
                            vaultStore.selectedDocumentID = welcome.id
                            workbench.showEditor()
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.spacing2) {
                                Text(welcome.resolvedPageIcon)
                                    .font(.system(size: 16))
                                Text("Open welcome tour")
                                    .font(OWTypography.bodyEmphasis)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.spacing4)
                            .padding(.vertical, DesignTokens.Spacing.spacing2)
                            .background(
                                DesignTokens.Color.surfaceElevated.opacity(0.95),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .center)

                if let welcome = vaultStore.documents.first(where: { $0.id == VaultDocument.welcomeDocumentID }) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                        Text("Starter layout")
                            .font(OWTypography.captionEmphasis)
                            .foregroundStyle(DesignTokens.Color.textTertiary)

                        ForEach(welcome.rootBlocks.filter { $0.kind != .property }.prefix(4)) { block in
                            OWPreviewBlockRow(block: block)
                        }
                    }
                    .openWriteEditorContentWidth(
                        readableMaxWidth: DesignTokens.Layout.editorMaxContentWidth
                    )
                    .padding(.top, DesignTokens.Spacing.spacing2)
                }
            }
            .padding(DesignTokens.Spacing.spacing5)
            .frame(maxWidth: .infinity, alignment: .top)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.editorCanvas)
    }
}
