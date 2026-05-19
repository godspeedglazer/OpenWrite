// Custom left rail — draggable width, no List / NavigationSplitView sidebar chrome.
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
                size: 18,
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
                .openWriteFocusChrome()
                .help("Clear search")
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .padding(.vertical, DesignTokens.Spacing.spacing2)
        .background(
            DesignTokens.Color.surface,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
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
    var onCollapse: (() -> Void)? = nil

    @State private var objectsSectionExpanded = true
    @State private var pinnedSectionExpanded = true
    @State private var spaceSwitcherExpanded = false

    private var activeVaultDocuments: [VaultDocument] {
        vaultStore.documentsInActiveVault
    }

    private var activeVaultTypeFilter: PageType? {
        workbench.vaultTypeFilter(for: vaultStore.activeVaultID)
    }

    private var filteredDocuments: [VaultDocument] {
        var docs = activeVaultDocuments
        if let filter = activeVaultTypeFilter {
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
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                    navigationRailBrandHeader
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
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(railBackground)
        .overlay(alignment: .topTrailing) {
            if let onCollapse {
                OWShellColumnCollapseButton(
                    icon: .collapseTrailing,
                    help: "Collapse sidebar",
                    action: onCollapse
                )
                .padding(.top, DesignTokens.Spacing.spacing2)
                .padding(.trailing, DesignTokens.Spacing.spacing1)
            }
        }
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

    private var navigationRailBrandHeader: some View {
        Text("OpenWrite")
            .font(OWTypography.bodyEmphasis)
            .foregroundStyle(DesignTokens.Color.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.spacing2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .accessibilityAddTraits(.isHeader)
    }

    /// Vault switcher — logical spaces (primary + demo) with per-vault object filters.
    private var spaceSwitcherStub: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
            HStack(spacing: DesignTokens.Spacing.spacing1) {
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
                .openWriteFocusChrome()
                .help(spaceSwitcherExpanded ? "Collapse vault menu" : "Expand vault menu")

                VStack(alignment: .leading, spacing: 2) {
                    Text(vaultStore.activeVault.name)
                        .font(OWTypography.sidebarItemEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                    Text(vaultStore.activeVault.subtitle)
                        .font(OWTypography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }

                Spacer(minLength: 0)

                OWUnicodePageTypeIconWell(icon: .notes, size: 20)

                Button {
                    showNewPageSheet = true
                } label: {
                    OWUnicodeIconView(icon: .plus, size: 16, color: DesignTokens.Color.accent)
                }
                .buttonStyle(.plain)
                .openWriteFocusChrome()
                .foregroundStyle(DesignTokens.Color.accent)
                .help("New page")
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing2)
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
            .accessibilityLabel("\(vaultStore.activeVault.name), \(vaultStore.activeVault.subtitle)")

            if spaceSwitcherExpanded {
                VStack(spacing: DesignTokens.Spacing.spacing1) {
                    ForEach(vaultStore.vaults) { vault in
                        let isActive = vault.id == vaultStore.activeVaultID
                        let pageCount = vaultStore.documents(in: vault.id).count
                        Button {
                            withAnimation(DesignTokens.Motion.animationStandard) {
                                vaultStore.switchVault(to: vault.id)
                                workbench.applyVaultContext(vault.id)
                            }
                        } label: {
                            HStack(spacing: DesignTokens.Spacing.spacing2) {
                                Text(isActive ? "●" : "○")
                                    .font(OWTypography.caption)
                                    .foregroundStyle(
                                        isActive ? DesignTokens.Color.accent : DesignTokens.Color.textTertiary
                                    )
                                    .frame(width: 16)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(vault.name)
                                        .font(OWTypography.sidebarItemEmphasis)
                                        .foregroundStyle(DesignTokens.Color.textPrimary)
                                    Text("\(pageCount) pages · \(vault.subtitle)")
                                        .font(OWTypography.caption)
                                        .foregroundStyle(DesignTokens.Color.textTertiary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, DesignTokens.Spacing.spacing2)
                            .padding(.vertical, DesignTokens.Spacing.spacing1)
                            .background(
                                isActive
                                    ? DesignTokens.Color.selectionPill.opacity(0.65)
                                    : Color.clear,
                                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                            )
                        }
                        .buttonStyle(.plain)
                    .openWriteFocusChrome()
                    }
                }
                .padding(.horizontal, DesignTokens.Spacing.spacing1)
                .padding(.bottom, DesignTokens.Spacing.spacing1)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private var objectsSection: some View {
        OWSidebarSection(title: "Objects", isExpanded: $objectsSectionExpanded) {
            VStack(spacing: DesignTokens.Spacing.spacing2) {
                ForEach(objectNavTypes, id: \.self) { type in
                    OWSidebarObjectTypeRow(
                        pageType: type,
                        documentCount: documentCount(for: type),
                        isFilterActive: activeVaultTypeFilter == type
                    ) {
                        withAnimation(DesignTokens.Motion.animationStandard) {
                            workbench.toggleVaultTypeFilter(type, for: vaultStore.activeVaultID)
                            workbench.showEditor()
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

    private func documentCount(for type: PageType) -> Int {
        activeVaultDocuments.filter { $0.pageType == type }.count
    }

    private var objectNavTypes: [PageType] {
        [.note, .task, .journal, .project, .reference, .collection]
    }

    private var vaultSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            HStack {
                OWNavigationRailSectionLabel(title: "Vault")
                Spacer()
                if activeVaultTypeFilter != nil {
                    Button("Clear filter") {
                        workbench.clearVaultTypeFilter(for: vaultStore.activeVaultID)
                    }
                    .font(OWTypography.caption)
                    .buttonStyle(.plain)
                    .openWriteFocusChrome()
                    .foregroundStyle(DesignTokens.Color.accent)
                }
            }

            if filteredDocuments.isEmpty {
                vaultEmptyCTA
            } else {
                VStack(spacing: DesignTokens.Spacing.spacing2) {
                ForEach(filteredDocuments) { doc in
                    OWSidebarRow(
                        title: doc.displayTitle,
                        pageType: doc.pageType,
                        pageIconCharacter: doc.resolvedPageIcon,
                        isSelected: vaultStore.selectedDocumentID == doc.id
                    ) {
                        vaultStore.selectedDocumentID = doc.id
                        vaultStore.selectedDatabaseID = nil
                        workbench.clearVaultTypeFilter(for: vaultStore.activeVaultID)
                        workbench.showEditor()
                    }
                }
                }
            }
        }
    }

    @ViewBuilder
    private var vaultEmptyCTA: some View {
        if let filter = activeVaultTypeFilter {
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
                vaultCTALabel("New \(filter.displayName.lowercased())")
            }
            .buttonStyle(.plain)
        .openWriteFocusChrome()
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
                vaultCTALabel("New page")
            }
            .buttonStyle(.plain)
        .openWriteFocusChrome()
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
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
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
                        isSelected: false
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
                .openWriteFocusChrome()
                }
            }
        }
    }

    private var railBottomActions: some View {
        VStack(spacing: DesignTokens.Spacing.spacing2) {
            if showsIngestionRailFooter {
                ingestionRailFooter
            }

            HStack(spacing: DesignTokens.Spacing.spacing3) {
                railBottomButton(icon: .settings, help: "Settings") {
                    showAISettings = true
                }

                OWNavigationRailThemeControl()

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

    /// Ingestion progress only when active or failed — LM Studio config stays in Settings.
    private var showsIngestionRailFooter: Bool {
        let health = aiServices.ingestionHealth.health
        return health.status == .failed || health.isActive || aiServices.isIndexing
    }

    private var ingestionRailFooter: some View {
        let health = aiServices.ingestionHealth.health
        return OWRoundedRect(style: .surface, padding: DesignTokens.Spacing.spacing2) {
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
                    Text("\(aiServices.indexedChunkCount) passages indexed")
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
            parts.append("\(aiServices.indexedChunkCount) passages indexed")
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
        .openWriteFocusChrome()
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

        if aiServices.lmConnectionState == .noModelLoaded {
            return DesignTokens.Color.warning
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
            return "Local AI connected · \(health.statusLabel.lowercased())"
        }

        if aiServices.lmConnectionState == .noModelLoaded {
            return "LM Studio reachable — load a chat model in LM Studio"
        }

        if aiServices.lmStatus == "Not checked" {
            return "Local AI not configured — open Settings"
        }

        return "Local AI · \(aiServices.lmStatus)"
    }
}

// MARK: - Rail theme control

/// Compact cycle + theme menu for the sidebar footer (same pattern as `ThemeQuickToggle`).
private struct OWNavigationRailThemeControl: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var pickerTheme: ThemeID = .openWriteLight

    private var buttonSize: CGFloat { DesignTokens.Layout.sidebarBottomButtonSize }

    var body: some View {
        let _ = themeManager.selectedTheme
        HStack(spacing: DesignTokens.Spacing.spacing1) {
            Button {
                themeManager.selectNext()
            } label: {
                railThemeMiniSwatch(themeManager.palette)
                    .frame(width: buttonSize, height: buttonSize)
                    .background(DesignTokens.Color.selectionPill.opacity(0.9), in: Circle())
                    .overlay {
                        Circle()
                            .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: 0.5)
                    }
            }
            .buttonStyle(.plain)
            .openWriteFocusChrome()
            .help("Cycle theme (\(themeManager.selectedTheme.displayName))")
            .accessibilityLabel("Cycle theme, currently \(themeManager.selectedTheme.displayName)")

            OWThemedDropdown(
                accessibilityLabel: "Choose theme",
                selection: $pickerTheme,
                options: Array(ThemeID.allCases),
                optionTitle: { $0.displayName },
                minWidth: 44,
                compact: true,
                leadingIcon: .sliders,
                iconOnly: true
            )
            .frame(width: buttonSize, height: buttonSize)
            .background(DesignTokens.Color.selectionPill.opacity(0.9), in: Circle())
            .overlay {
                Circle()
                    .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: 0.5)
            }
            .onAppear { pickerTheme = themeManager.selectedTheme }
            .onChange(of: pickerTheme) { _, theme in
                themeManager.select(theme)
            }
            .onChange(of: themeManager.selectedTheme) { _, theme in
                pickerTheme = theme
            }
            .help("Choose theme (\(themeManager.selectedTheme.displayName))")
        }
    }

    private func railThemeMiniSwatch(_ palette: ThemePalette) -> some View {
        HStack(spacing: 0) {
            palette.sidebarBackground.frame(width: 9)
            VStack(spacing: 0) {
                palette.workbenchChrome.frame(height: 5)
                palette.editorCanvas
                palette.accent.frame(height: 3)
            }
        }
        .clipShape(Circle())
        .accessibilityHidden(true)
    }
}

/// Icon-rail variant: swatch cycles on tap; sliders opens the theme list popover.
private struct OWNavigationRailCollapsedThemeControl: View {
    @Environment(ThemeManager.self) private var themeManager
    @State private var pickerTheme: ThemeID = .openWriteLight

    var body: some View {
        let _ = themeManager.selectedTheme
        VStack(spacing: DesignTokens.Spacing.spacing1) {
            Button {
                themeManager.selectNext()
            } label: {
                railThemeMiniSwatch(themeManager.palette)
                    .frame(width: 36, height: 36)
                    .background(
                        palette.surface.opacity(0.55),
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .openWriteFocusChrome()
            .help("Cycle theme (\(themeManager.selectedTheme.displayName))")
            .accessibilityLabel("Cycle theme, currently \(themeManager.selectedTheme.displayName)")

            OWThemedDropdown(
                accessibilityLabel: "Choose theme",
                selection: $pickerTheme,
                options: Array(ThemeID.allCases),
                optionTitle: { $0.displayName },
                minWidth: 44,
                compact: true,
                leadingIcon: .sliders,
                iconOnly: true
            )
            .frame(width: 36, height: 36)
            .background(
                palette.surface.opacity(0.55),
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
            )
            .onAppear { pickerTheme = themeManager.selectedTheme }
            .onChange(of: pickerTheme) { _, theme in
                themeManager.select(theme)
            }
            .onChange(of: themeManager.selectedTheme) { _, theme in
                pickerTheme = theme
            }
            .help("Choose theme (\(themeManager.selectedTheme.displayName))")
        }
    }

    @Environment(\.openWritePalette) private var palette

    private func railThemeMiniSwatch(_ palette: ThemePalette) -> some View {
        HStack(spacing: 0) {
            palette.sidebarBackground.frame(width: 10)
            VStack(spacing: 0) {
                palette.workbenchChrome.frame(height: 6)
                palette.editorCanvas
                palette.accent.frame(height: 4)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous))
        .accessibilityHidden(true)
    }
}

// MARK: - Collapsed icon rail

/// Narrow (~48pt) navigation rail when the full sidebar is collapsed.
struct OWNavigationRailCollapsed: View {
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.openWritePalette) private var palette
    @EnvironmentObject private var vaultStore: VaultStore
    @ObservedObject var workbench: WorkbenchState
    @Binding var showNewPageSheet: Bool
    @Binding var showAISettings: Bool
    let onExpand: () -> Void

    private let objectNavTypes: [PageType] = [.note, .task, .journal, .project, .reference, .collection]

    private var activeVaultTypeFilter: PageType? {
        workbench.vaultTypeFilter(for: vaultStore.activeVaultID)
    }

    var body: some View {
        VStack(spacing: DesignTokens.Spacing.spacing2) {
            OWShellColumnCollapseButton(
                icon: .chevronRight,
                help: "Expand sidebar",
                action: onExpand
            )

            ForEach(objectNavTypes, id: \.self) { type in
                collapsedTypeButton(type)
            }

            collapsedIconButton(
                icon: .graph,
                help: "Graph",
                isActive: workbench.centerTab == .graph
            ) {
                withAnimation(DesignTokens.Motion.animationStandard) {
                    workbench.showGraph()
                }
            }

            Spacer(minLength: 0)

            collapsedIconButton(icon: .plus, help: "New page") {
                showNewPageSheet = true
            }

            OWNavigationRailCollapsedThemeControl()

            collapsedIconButton(icon: .settings, help: "Settings") {
                showAISettings = true
            }
        }
        .padding(.vertical, DesignTokens.Spacing.spacing3)
        .padding(.horizontal, DesignTokens.Spacing.spacing1)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(palette.sidebarBackground)
        .overlay(alignment: .trailing) {
            Rectangle()
                .fill(DesignTokens.Color.borderSubtle)
                .frame(width: DesignTokens.Layout.borderWidth)
        }
    }

    private func collapsedTypeButton(_ type: PageType) -> some View {
        let isFilterActive = activeVaultTypeFilter == type
        return collapsedIconButton(
            icon: type.owIcon,
            help: type.displayName,
            isActive: isFilterActive
        ) {
            withAnimation(DesignTokens.Motion.animationStandard) {
                workbench.toggleVaultTypeFilter(type, for: vaultStore.activeVaultID)
                workbench.showEditor()
            }
        }
    }

    private func collapsedIconButton(
        icon: OWIcon,
        help: String,
        isActive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            OWUnicodeIconView(
                icon: icon,
                size: 16,
                color: isActive ? DesignTokens.Color.accent : DesignTokens.Color.textSecondary
            )
            .frame(width: 36, height: 36)
            .background(
                isActive
                    ? palette.selectionPill
                    : palette.surface.opacity(0.55),
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
            )
            .overlay {
                if isActive {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                        .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: DesignTokens.Layout.borderWidth)
                }
            }
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .help(help)
    }
}

// MARK: - Column collapse control

struct OWShellColumnCollapseButton: View {
    let icon: OWUnicodeIcon
    let help: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            OWUnicodeIconView(icon, size: 12, color: DesignTokens.Color.textSecondary)
                .frame(width: 28, height: 28)
                .background(
                    DesignTokens.Color.surface.opacity(0.85),
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                        .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: DesignTokens.Layout.borderWidth)
                }
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .help(help)
    }
}
