// Custom left rail — fixed width, no List / NavigationSplitView sidebar chrome.
// See docs/design/SidebarPhilosophy.md.

import SwiftUI

// MARK: - Section label

struct OWNavigationRailSectionLabel: View {
    let title: String

    var body: some View {
        Text(title.uppercased())
            .font(OWTypography.railSectionLabel)
            .tracking(OWTypography.railSectionTracking)
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
            OWUnicodeIconView(
                icon: .search,
                size: 14,
                color: isFocused ? DesignTokens.Color.textSecondary : DesignTokens.Color.textTertiary
            )

            TextField(placeholder, text: $text)
                .textFieldStyle(.plain)
                .font(OWTypography.sidebarItem)
                .foregroundStyle(DesignTokens.Color.textPrimary)
                .focused($isFocused)

            if !text.isEmpty {
                Button {
                    text = ""
                } label: {
                    OWUnicodeIconView(icon: .plus, size: 12, color: DesignTokens.Color.textTertiary)
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
    @Environment(\.openWritePalette) private var palette
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var aiServices: OpenWriteAIServices

    @ObservedObject var workbench: WorkbenchState
    @Binding var searchQuery: String
    @Binding var showNewPageSheet: Bool
    @Binding var showAISettings: Bool
    @Binding var showCreateDatabaseSheet: Bool

    @State private var objectsSectionExpanded = true
    @State private var pinnedSectionExpanded = true
    @State private var spaceSwitcherExpanded = false

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
        let _ = themeManager.selectedTheme
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
                    spaceSwitcherStub
                    OWRailSearchField(text: $searchQuery)
                    objectsSection
                    DatabaseListView(
                        workbench: workbench,
                        showCreateDatabaseSheet: $showCreateDatabaseSheet
                    )
                    vaultSection
                    pinnedSection
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
            palette.sidebarBackground
            LinearGradient(
                colors: [
                    palette.textPrimary.opacity(0.03),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        }
    }

    /// Optional space switcher stub (Anytype-style space row at rail top).
    private var spaceSwitcherStub: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
            HStack(spacing: DesignTokens.Spacing.spacing2) {
                Button {
                    withAnimation(DesignTokens.Motion.animationStandard) {
                        spaceSwitcherExpanded.toggle()
                    }
                } label: {
                    Text(spaceSwitcherExpanded ? "▾" : "▸")
                        .font(OWTypography.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                        .frame(width: 20, alignment: .center)
                }
                .buttonStyle(.plain)
                .help(spaceSwitcherExpanded ? "Collapse space menu" : "Expand space menu")

                OWUnicodePageTypeIconWell(icon: .notes, size: 22)

                VStack(alignment: .leading, spacing: 2) {
                    Text("OpenWrite")
                        .font(OWTypography.bodyEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                    Text("Local vault")
                        .font(OWTypography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }

                Spacer(minLength: 0)

                Button {
                    showNewPageSheet = true
                } label: {
                    OWUnicodeIconView(icon: .plus, size: 16, color: DesignTokens.Color.accent)
                }
                .buttonStyle(.plain)
                .foregroundStyle(DesignTokens.Color.accent)
                .help("New page")
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing1)
            .padding(.vertical, DesignTokens.Spacing.spacing1)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .fill(DesignTokens.Color.surface.opacity(spaceSwitcherExpanded ? 0.85 : 0.55))
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: DesignTokens.Layout.borderWidth)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("OpenWrite, local vault")
            .accessibilityHint("Space switcher coming soon")

            if spaceSwitcherExpanded {
                Text("Additional spaces will appear here. For now, everything lives in your local vault.")
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                    .padding(.horizontal, DesignTokens.Spacing.spacing2)
                    .padding(.bottom, DesignTokens.Spacing.spacing1)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var objectsSection: some View {
        OWSidebarSection(title: "Objects", isExpanded: $objectsSectionExpanded) {
            VStack(spacing: 0) {
                ForEach(objectNavTypes, id: \.self) { type in
                    OWSidebarObjectTypeRow(
                        pageType: type,
                        documentCount: documentCount(for: type),
                        isFilterActive: workbench.vaultTypeFilter == type
                    ) {
                        withAnimation(DesignTokens.Motion.animationStandard) {
                            if workbench.vaultTypeFilter == type {
                                workbench.vaultTypeFilter = nil
                            } else {
                                workbench.vaultTypeFilter = type
                                workbench.showEditor()
                            }
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

    private func documentCount(for type: PageType) -> Int {
        vaultStore.documents.filter { $0.pageType == type }.count
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
                    .font(OWTypography.caption)
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignTokens.Color.accent)
                }
            }

            if filteredDocuments.isEmpty {
                vaultEmptyCTA
            } else {
                ForEach(filteredDocuments) { doc in
                    OWSidebarRow(
                        title: doc.displayTitle,
                        pageType: doc.pageType,
                        pageIconCharacter: doc.resolvedPageIcon,
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

    @ViewBuilder
    private var vaultEmptyCTA: some View {
        if let filter = workbench.vaultTypeFilter {
            let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if q.isEmpty {
                Text("No \(filter.displayName.lowercased()) pages yet.")
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            } else {
                Text("No matches for “\(q)” in \(filter.displayName.lowercased()) pages.")
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            }

            Button {
                let doc = vaultStore.createDocument(pageType: filter, title: nil)
                vaultStore.selectedDocumentID = doc.id
                vaultStore.selectedDatabaseID = nil
                workbench.showEditor()
            } label: {
                vaultCTALabel("+ New \(filter.displayName.lowercased())")
            }
            .buttonStyle(.plain)
        } else {
            let q = searchQuery.trimmingCharacters(in: .whitespacesAndNewlines)
            if !q.isEmpty {
                Text("No vault pages match “\(q)”.")
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
            }

            Button {
                showNewPageSheet = true
            } label: {
                vaultCTALabel("+ New page")
            }
            .buttonStyle(.plain)
        }
    }

    private func vaultCTALabel(_ title: String) -> some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            OWUnicodeIconView(icon: .plus, size: 14, color: palette.accent)
            Text(title)
                .font(OWTypography.sidebarItemEmphasis)
                .foregroundStyle(palette.accent)
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .padding(.vertical, DesignTokens.Spacing.spacing1)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            palette.selectionPill.opacity(0.75),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
        )
    }

    private var pinnedSection: some View {
        OWSidebarSection(title: "Pinned", isExpanded: $pinnedSectionExpanded) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                Text("Keep important pages at the top of your vault.")
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)

                if let doc = vaultStore.selectedDocument {
                        OWSidebarRow(
                            title: doc.displayTitle,
                            pageType: doc.pageType,
                            pageIconCharacter: doc.resolvedPageIcon,
                            dense: true,
                            isSelected: true
                        ) {
                        workbench.showEditor()
                    }
                } else {
                    Button {
                        showNewPageSheet = true
                    } label: {
                        vaultCTALabel("Open a page to pin")
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(DesignTokens.Spacing.spacing1)
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
                    .help(aiStatusHelp)
                    .accessibilityLabel(aiStatusHelp)
            }
        }
        .padding(DesignTokens.Spacing.sidebarPadding)
        .background(
            LinearGradient(
                colors: [
                    palette.sidebarBackground.opacity(0),
                    palette.sidebarBackground
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }

    private var ingestionRailFooter: some View {
        let health = aiServices.ingestionHealth.health
        return OWRoundedRect(style: .sidebarCard, padding: DesignTokens.Spacing.spacing2) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
                HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.spacing2) {
                    Text("Ingestion")
                        .font(OWTypography.captionEmphasis)
                        .foregroundStyle(palette.textSecondary)
                    Spacer(minLength: DesignTokens.Spacing.spacing1)
                    Text(health.statusLabel)
                        .font(OWTypography.captionEmphasis)
                        .foregroundStyle(palette.textPrimary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.85)
                }

                if health.status == .failed, let error = health.lastError, !error.isEmpty {
                    Text(error)
                        .font(OWTypography.caption)
                        .foregroundStyle(palette.danger)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                        .help(error)
                } else if health.isActive || aiServices.isIndexing {
                    if let summary = health.progressSummary {
                        Text(summary)
                            .font(OWTypography.caption)
                            .foregroundStyle(palette.textSecondary)
                            .lineLimit(2)
                    }
                    ProgressView(value: health.progressFraction)
                        .controlSize(.small)
                        .tint(palette.accent)
                } else {
                    Text("\(aiServices.indexedChunkCount) chunks indexed")
                        .font(OWTypography.caption)
                        .foregroundStyle(palette.textSecondary)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(ingestionAccessibilityLabel(health: health))
    }

    private func ingestionAccessibilityLabel(health: IngestionHealth) -> String {
        var parts = ["Vault ingestion", health.statusLabel]
        if health.isActive, let summary = health.progressSummary {
            parts.append(summary)
        } else {
            parts.append("\(aiServices.indexedChunkCount) chunks indexed")
        }
        if let error = health.lastError, !error.isEmpty {
            parts.append(error)
        }
        return parts.joined(separator: ", ")
    }

    private func railBottomButton(icon: OWIcon, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            OWUnicodeIconView(icon: icon, size: 16, color: DesignTokens.Color.textSecondary)
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
        let health = aiServices.ingestionHealth.health

        if health.status == .failed {
            return DesignTokens.Color.danger
        }

        if aiServices.isIndexing
            || health.isActive
            || aiServices.activityState == .indexing {
            return DesignTokens.Color.warning
        }

        if aiServices.isLMStudioConnected {
            return DesignTokens.Color.success
        }

        return DesignTokens.Color.textTertiary
    }

    private var aiStatusHelp: String {
        let health = aiServices.ingestionHealth.health

        if health.status == .failed {
            if let error = health.lastError, !error.isEmpty {
                return "Ingestion failed: \(error)"
            }
            return "Ingestion failed"
        }

        if aiServices.isIndexing
            || health.isActive
            || aiServices.activityState == .indexing {
            return aiServices.activityState.statusMessage ?? health.progressSummary ?? health.statusLabel
        }

        if aiServices.isLMStudioConnected {
            return "LM Studio connected · \(health.statusLabel.lowercased())"
        }

        if aiServices.lmStatus == "Not checked" {
            return "LM Studio not checked — open Settings to connect"
        }

        return aiServices.lmStatus
    }
}
