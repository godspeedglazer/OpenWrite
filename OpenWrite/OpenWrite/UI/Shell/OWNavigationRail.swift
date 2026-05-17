// Custom left rail — fixed width, no List / NavigationSplitView sidebar chrome.
// See docs/design/SidebarPhilosophy.md.

import SwiftUI

// MARK: - Section label

struct OWNavigationRailSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(DesignTokens.Typography.railSectionLabel)
            .tracking(DesignTokens.Typography.railSectionTracking)
            .foregroundStyle(DesignTokens.Color.textTertiary)
            .padding(.horizontal, DesignTokens.Spacing.spacing2)
            .padding(.top, DesignTokens.Spacing.spacing1)
            .accessibilityAddTraits(.isHeader)
    }
}

// MARK: - Search

struct OWRailSearchField: View {
    @Binding var text: String
    var placeholder: String = "Search vault…"

    @FocusState private var isFocused: Bool

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            OWIconView(
                icon: .search,
                size: 14,
                color: isFocused ? DesignTokens.Color.textSecondary : DesignTokens.Color.textTertiary
            )

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(DesignTokens.Typography.sidebarItem)
                .foregroundStyle(DesignTokens.Color.textPrimary)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    OWIconView(icon: .plus, size: 12, color: DesignTokens.Color.textTertiary)
                        .rotationEffect(.degrees(45))
                }
                .buttonStyle(.plain)
                .help("Clear search")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .padding(.vertical, DesignTokens.Spacing.spacing2)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .fill(DesignTokens.Color.surface.opacity(isFocused ? 0.95 : 0.72))
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .strokeBorder(
                    isFocused ? DesignTokens.Color.accent.opacity(0.45) : DesignTokens.Color.borderHairline,
                    lineWidth: DesignTokens.Layout.borderWidth
                )
        }
        .animation(DesignTokens.Motion.animationFast, value: isFocused)
    }
}

// MARK: - Rail

struct OWNavigationRail: View {
    @Environment(ThemeManager.self) private var themeManager
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var aiServices: OpenWriteAIServices

    @ObservedObject var workbench: WorkbenchState
    @Binding var searchQuery: String
    @Binding var showNewPageSheet: Bool
    @Binding var showAISettings: Bool
    @Binding var showCreateDatabaseSheet: Bool

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
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
                    spaceHeader
                    OWRailSearchField(text: $searchQuery)
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

            railBottomActions
        }
        .frame(width: DesignTokens.Layout.navigationRailWidth)
        .background(railBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DesignTokens.Color.borderSubtle)
                .frame(width: DesignTokens.Layout.borderWidth)
        }
    }

    private var railBackground: some View {
        ZStack {
            DesignTokens.Color.sidebarBackground
            LinearGradient(
                colors: [
                    DesignTokens.Color.textPrimary.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    private var spaceHeader: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            OWPageTypeIconWell(icon: .notes, size: 22)

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

    private var objectsSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            OWNavigationRailSectionLabel(title: "Objects")

            OWRoundedRect(style: .sidebarCard, padding: DesignTokens.Spacing.spacing1) {
                VStack(spacing: 0) {
                    ForEach(objectNavTypes, id: \.self) { type in
                        OWSidebarRow(
                            title: type.displayName,
                            pageType: type,
                            dense: true,
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
                        dense: true,
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

    private var objectNavTypes: [PageType] {
        [.note, .task, .journal, .project, .reference, .collection]
    }

    private var vaultSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            HStack {
                OWNavigationRailSectionLabel(title: "Vault")
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
                Button {
                    showNewPageSheet = true
                } label: {
                    HStack(spacing: DesignTokens.Spacing.spacing2) {
                        OWIconView(icon: .plus, size: 14, color: DesignTokens.Color.accent)
                        Text("+ New page")
                            .font(DesignTokens.Typography.sidebarItem.weight(.medium))
                            .foregroundStyle(DesignTokens.Color.accent)
                    }
                    .padding(.horizontal, DesignTokens.Spacing.spacing2)
                    .padding(.vertical, DesignTokens.Spacing.spacing1)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(
                        DesignTokens.Color.selectionPill.opacity(0.75),
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    )
                }
                .buttonStyle(.plain)
            } else {
                ForEach(filteredDocuments) { doc in
                    OWSidebarRow(
                        title: doc.displayTitle,
                        pageType: doc.pageType,
                        dense: true,
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
            OWNavigationRailSectionLabel(title: "Pinned")
            OWRoundedRect(style: .sidebarCard, padding: DesignTokens.Spacing.spacing2) {
                Text("Pin pages here soon.")
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            }
        }
    }

    private var railBottomActions: some View {
        VStack(spacing: DesignTokens.Spacing.spacing2) {
            ingestionRailFooter

            HStack(spacing: DesignTokens.Spacing.spacing3) {
                railBottomButton(icon: .settings, help: "Settings") {
                    showAISettings = true
                }

                railBottomButton(
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

    private var ingestionRailFooter: some View {
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

    private func railBottomButton(icon: OWIcon, help: String, action: @escaping () -> Void) -> some View {
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
}
