// Anytype / Logseq-inspired workbench shell (clean-room SwiftUI).
// Layout widths: WorkbenchLayoutCoordinator (Phase 2 spine) — no nested preference chains.

import SwiftUI

struct AnytypeShellView: View {
    @Environment(\.openWritePalette) private var palette
    @Environment(ThemeManager.self) private var themeManager
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
    @State private var centerLayout: WorkbenchCenterLayout = WorkbenchLayoutCoordinator.resolve(
        centerRegionWidth: DesignTokens.Layout.windowDefaultWidth
            - DesignTokens.Layout.sidebarMinWidth,
        assistExpanded: ShellChromePreferences.assistStripExpanded,
        preferredAssistWidth: ShellChromePreferences.assistStripWidth
    )

    var body: some View {
        let _ = themeManager.revision
        VStack(spacing: 0) {
            OWShellTitleBar(
                tabs: centerTabBarItems,
                selectedTab: workbench.centerTab,
                onSelectTab: selectCenterTab,
                brandAlignsWithNavigationRail: workbench.sidebarVisible && !workbench.navigationRailCollapsed
            )

            shellBody
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .animation(DesignTokens.Motion.animationStandard, value: workbench.sidebarVisible)
        .animation(DesignTokens.Motion.animationStandard, value: workbench.navigationRailCollapsed)
        .background(palette.shellChrome.ignoresSafeArea())
        .environment(\.workbenchCenterLayout, centerLayout)
        .environment(\.editorWorkbenchWidth, centerLayout.editorBodyWidth)
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
        .onChange(of: vaultStore.databases.map(\.id)) { _, databaseIDs in
            if case .database(let active) = workbench.centerTab,
               !databaseIDs.contains(active.id) {
                workbench.showEditor()
            }
        }
        .onAppear {
            if workbench.navigationRailCollapsed {
                navigationRailWidth = DesignTokens.Layout.navigationRailCollapsedWidth
            }
        }
    }

    private var shellBody: some View {
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
                        .overlay(alignment: .trailing) {
                            shellColumnDivider
                        }
                        .transition(.move(edge: .leading).combined(with: .opacity))
                } trailing: {
                    centerWorkbench
                }
            } else {
                centerWorkbench
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .ignoresSafeArea(edges: .top)
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
            let regionWidth = geometry.size.width
            let layout = WorkbenchLayoutCoordinator.resolve(
                centerRegionWidth: regionWidth,
                assistExpanded: workbench.aiAssistExpanded,
                preferredAssistWidth: assistStripWidth
            )

            centerWorkbenchColumns(layout: layout)
                .frame(
                    width: layout.paddedInnerWidth,
                    height: geometry.size.height,
                    alignment: .topLeading
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .padding(.horizontal, DesignTokens.Layout.centerCardOuterPadding)
                .padding(.bottom, DesignTokens.Layout.centerCardOuterPadding)
                .environment(\.workbenchCenterLayout, layout)
                .environment(\.editorWorkbenchWidth, layout.editorBodyWidth)
                .environment(\.aiAssistStripWidth, layout.assistColumnWidth)
                .onChange(of: layout, initial: true) { _, resolved in
                    guard centerLayout != resolved else { return }
                    centerLayout = resolved
                }
                .onChange(of: regionWidth) { _, width in
                    handleCenterRegionWidthChange(width)
                }
                .onChange(of: workbench.aiAssistExpanded) { _, expanded in
                    if expanded, WorkbenchLayoutCoordinator.shouldCollapseAssist(centerRegionWidth: regionWidth) {
                        withAnimation(DesignTokens.Motion.animationStandard) {
                            workbench.aiAssistExpanded = false
                            workbench.persistChromePreferences()
                        }
                    }
                }
                .onChange(of: assistStripWidth) { _, width in
                    let resolved = WorkbenchLayoutCoordinator.resolve(
                        centerRegionWidth: regionWidth,
                        assistExpanded: workbench.aiAssistExpanded,
                        preferredAssistWidth: width
                    )
                    if resolved.assistColumnWidth > 0,
                       abs(width - resolved.assistColumnWidth) > 0.5 {
                        assistStripWidth = resolved.assistColumnWidth
                        ShellChromePreferences.assistStripWidth = resolved.assistColumnWidth
                    }
                }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.workbenchChrome)
    }

    @ViewBuilder
    private func centerWorkbenchColumns(layout: WorkbenchCenterLayout) -> some View {
        if workbench.aiAssistExpanded, layout.assistColumnWidth > 0 {
            HStack(alignment: .top, spacing: 0) {
                centerEditorColumn
                    .frame(width: layout.editorColumnWidth, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .top)

                WorkbenchAssistColumnDivider(
                    assistWidth: $assistStripWidth,
                    minWidth: DesignTokens.Layout.assistStripMinWidth,
                    maxWidth: DesignTokens.Layout.assistStripMaxWidth,
                    availableWidth: layout.paddedInnerWidth
                )

                assistColumn
                    .frame(width: layout.assistColumnWidth, alignment: .topLeading)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .overlay(alignment: .leading) {
                        shellColumnDivider
                    }
            }
        } else {
            centerEditorColumn
                .frame(width: layout.paddedInnerWidth, alignment: .topLeading)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    private var shellColumnDivider: some View {
        Rectangle()
            .fill(palette.borderSubtle)
            .frame(width: DesignTokens.Layout.borderWidth)
    }

    private func handleCenterRegionWidthChange(_ regionWidth: CGFloat) {
        if workbench.aiAssistExpanded,
           WorkbenchLayoutCoordinator.shouldCollapseAssist(centerRegionWidth: regionWidth) {
            withAnimation(DesignTokens.Motion.animationStandard) {
                workbench.aiAssistExpanded = false
                workbench.persistChromePreferences()
            }
        }
    }

    private var assistColumn: some View {
        AIAssistStripView(workbench: workbench, pastWrites: pastWrites) {
            withAnimation(DesignTokens.Motion.animationStandard) {
                workbench.aiAssistExpanded = false
                workbench.persistChromePreferences()
            }
        }
        .transition(.move(edge: .trailing).combined(with: .opacity))
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
        .workbenchAssistBottomBarEnvironment(active: !workbench.aiAssistExpanded)
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
                vaultStore.selectedDocumentID = nil
                vaultStore.selectedDatabaseID = database.id
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
                        vaultID: vaultStore.activeVaultID,
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
                    .id(vaultStore.activeVaultID)
                    .id(workbench.graphRefreshToken)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.large, style: .continuous))
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
            EditorView(document: doc)
                .id(doc.id)
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
                    .openWriteFocusChrome()

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
                        .openWriteFocusChrome()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                if let welcome = vaultStore.documents.first(where: { $0.id == VaultDocument.welcomeDocumentID }) {
                    VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                        Text("Starter layout")
                            .font(OWTypography.captionEmphasis)
                            .foregroundStyle(DesignTokens.Color.textTertiary)

                        ForEach(welcome.rootBlocks.filter { $0.kind != .property }.prefix(4)) { block in
                            OWPreviewBlockRow(block: block)
                        }
                    }
                    .openWriteEditorContentWidth()
                    .padding(.top, DesignTokens.Spacing.spacing2)
                }
            }
            .openWriteEditorLeadingInset()
            .padding(.vertical, DesignTokens.Spacing.spacing5)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(palette.editorCanvas)
    }
}
