import AppKit
import SwiftUI

// MARK: - OWPageHeaderEditor
//
// Clean-room page header inspired by Anytype desktop patterns (ASAL — no copied code).
// Reference paths studied in anytype-ts-develop:
//   - src/ts/component/page/elements/head/editor.tsx (PageHeadEditor — cover + IconPage blocks)
//   - src/ts/component/page/elements/head/simple.tsx (headSimple title/description stack)
//   - src/ts/component/block/iconPage.tsx (BlockIconPage — editable page emoji)
//   - src/ts/component/block/cover.tsx (BlockCover — cover strip + drag offsets)
// See also docs/design/AnytypeUIInspiration.md § Page hero.

/// Editable Anytype-style page header: cover strip, draggable emoji icon, title field, toolbar chips.
struct OWPageHeaderEditor<Metadata: View>: View {
    @Environment(\.openWritePalette) private var palette
    @EnvironmentObject private var vaultStore: VaultStore

    let documentID: UUID
    @Binding var title: String
    @Binding var pageIcon: String
    @Binding var coverStyle: CoverStyle?
    @Binding var coverImagePath: String?
    @Binding var pageIconOffsetX: CGFloat
    @Binding var pageIconOffsetY: CGFloat
    @ViewBuilder var metadata: () -> Metadata

    @State private var showCoverPicker = false
    @State private var showDescriptionField = false
    @State private var descriptionText = ""
    @State private var showEmojiPicker = false
    @State private var showPageOptions = false
    @State private var dragBaseOffset = CGSize.zero

    private var document: VaultDocument? {
        vaultStore.documents.first { $0.id == documentID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            bannerSection

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                if OWTypography.showsBundledSerifWarningInUI {
                    OWTypographyFontWarningBanner()
                }

                titleRow

                if showDescriptionField {
                    descriptionField
                }

                metadata()
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, bannerContentTopInset)
            .padding(.horizontal, DesignTokens.Layout.editorContentLeadingInset)
            .padding(.bottom, DesignTokens.Spacing.spacing2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { syncDescriptionFromDocument() }
        .onChange(of: documentID) { _, _ in syncDescriptionFromDocument() }
        .sheet(isPresented: $showCoverPicker) {
            OWCoverStylePickerSheet(
                documentID: documentID,
                selection: $coverStyle,
                coverImagePath: $coverImagePath
            ) {
                commitHeaderFields()
            }
        }
    }

    // MARK: - Banner

    private var bannerSection: some View {
        ZStack(alignment: .bottomLeading) {
            Button {
                showCoverPicker = true
            } label: {
                OWPageBannerGradient(
                    coverStyle: coverStyle,
                    coverImagePath: coverImagePath,
                    documentID: documentID,
                    pageType: document?.pageType,
                    stripHeight: OWPageBannerMetrics.stripHeight
                )
            }
            .buttonStyle(.plain)
            .openWriteFocusChrome()
            .help("Change cover")

            pageIconChip
                .padding(.leading, DesignTokens.Layout.editorContentLeadingInset + pageIconOffsetX)
                .offset(y: OWPageBannerMetrics.iconOverlap + pageIconOffsetY)
                .gesture(iconDragGesture)
        }
        .frame(height: OWPageBannerMetrics.stripHeight + OWPageBannerMetrics.iconOverlap)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var pageIconChip: some View {
        let displayIcon = pageIcon.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? (document?.resolvedPageIcon ?? PageType.note.unicodeCharacter)
            : pageIcon

        return Button {
            showEmojiPicker = true
        } label: {
            Text(displayIcon)
                .font(.system(size: 28))
                .frame(width: OWPageBannerMetrics.iconSize, height: OWPageBannerMetrics.iconSize)
                .background(
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                        .fill(palette.editorCanvas)
                )
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                        .strokeBorder(palette.editorCanvas, lineWidth: 2)
                }
                .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .help("Change page icon")
        .popover(isPresented: $showEmojiPicker, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            OWPageIconPicker { pick in
                if let normalized = OWUnicodeSymbolCatalog.normalizedPick(pick) {
                    pageIcon = normalized
                    showEmojiPicker = false
                    commitHeaderFields()
                }
            }
            .padding(DesignTokens.Spacing.spacing2)
            .presentationBackground(DesignTokens.Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
            }
        }
        .accessibilityLabel("Page icon")
    }

    private var iconDragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                if dragBaseOffset == .zero {
                    dragBaseOffset = CGSize(width: pageIconOffsetX, height: pageIconOffsetY)
                }
                let proposed = CGSize(
                    width: dragBaseOffset.width + value.translation.width,
                    height: dragBaseOffset.height + value.translation.height
                )
                pageIconOffsetX = min(max(proposed.width, -48), 120)
                pageIconOffsetY = min(max(proposed.height, -32), 48)
            }
            .onEnded { _ in
                dragBaseOffset = .zero
                commitHeaderFields()
            }
    }

    private var bannerContentTopInset: CGFloat {
        OWPageBannerMetrics.iconOverlap + DesignTokens.Spacing.spacing2
    }

    // MARK: - Title & page options

    private var titleRow: some View {
        HStack(alignment: .firstTextBaseline, spacing: DesignTokens.Spacing.spacing2) {
            titleField
                .layoutPriority(1)

            pageOptionsMenu
        }
    }

    private var pageOptionsMenu: some View {
        Button {
            showPageOptions = true
        } label: {
            Text("⋯")
                .font(OWTypography.captionEmphasis)
                .foregroundStyle(DesignTokens.Color.textTertiary)
                .frame(width: 28, height: 28)
                .background(
                    Circle()
                        .fill(DesignTokens.Color.surface.opacity(0.85))
                )
                .overlay {
                    Circle()
                        .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: 0.5)
                }
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .fixedSize()
        .help("Page options")
        .popover(isPresented: $showPageOptions, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
                pageOptionsRow("Change cover…") {
                    showPageOptions = false
                    showCoverPicker = true
                }
                pageOptionsRow(showDescriptionField ? "Hide description" : "Add description") {
                    showPageOptions = false
                    withAnimation(.easeOut(duration: 0.18)) {
                        showDescriptionField.toggle()
                        if showDescriptionField, descriptionText.isEmpty {
                            syncDescriptionFromDocument()
                        }
                    }
                }
                pageOptionsRow("Change icon…") {
                    showPageOptions = false
                    showEmojiPicker = true
                }
                Divider().padding(.vertical, 2)
                pageOptionsRow("Reset icon position") {
                    showPageOptions = false
                    pageIconOffsetX = 0
                    pageIconOffsetY = 0
                    commitHeaderFields()
                }
                pageOptionsRow("Remove cover", destructive: true) {
                    showPageOptions = false
                    coverStyle = nil
                    commitHeaderFields()
                }
            }
            .padding(DesignTokens.Spacing.spacing2)
            .frame(minWidth: 200)
            .presentationBackground(DesignTokens.Color.surfaceElevated)
            .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
            }
        }
    }

    private func pageOptionsRow(
        _ title: String,
        destructive: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .font(OWTypography.callout)
                .foregroundStyle(destructive ? DesignTokens.Color.danger : DesignTokens.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, DesignTokens.Spacing.spacing2)
                .padding(.vertical, 6)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    .openWriteFocusChrome()
    }

    private var titleField: some View {
        TextField("Untitled", text: $title, axis: .vertical)
            .font(OWTypography.documentTitle)
            .lineSpacing(OWTypography.documentTitleLineSpacing)
            .foregroundStyle(DesignTokens.Color.textPrimary)
            .textFieldStyle(.plain)
            .lineLimit(1 ... 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .fixedSize(horizontal: false, vertical: true)
            .onSubmit { commitTitle() }
            .onChange(of: title) { _, _ in commitTitle() }
    }

    private var descriptionField: some View {
        TextField("Add a description…", text: $descriptionText, axis: .vertical)
            .font(OWTypography.callout)
            .foregroundStyle(DesignTokens.Color.textSecondary)
            .textFieldStyle(.plain)
            .lineLimit(1 ... 4)
            .onChange(of: descriptionText) { _, newValue in
                commitDescription(newValue)
            }
    }

    // MARK: - Persistence

    private func syncDescriptionFromDocument() {
        guard let document else { return }
        descriptionText = document.properties.string(for: .summary)
        showDescriptionField = !descriptionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private func commitTitle() {
        guard var doc = document else { return }
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let resolved = trimmed.isEmpty ? "Untitled" : trimmed
        guard resolved != doc.title else { return }
        doc.title = resolved
        doc.properties.setText(resolved, for: .title)
        vaultStore.updateDocument(doc)
    }

    private func commitDescription(_ text: String) {
        guard var doc = document else { return }
        guard text != doc.properties.string(for: .summary) else { return }
        doc.properties.setText(text, for: .summary)
        vaultStore.updateDocument(doc)
    }

    private func commitHeaderFields() {
        guard var doc = document else { return }
        doc.pageIcon = pageIcon
        doc.coverStyle = coverStyle
        doc.coverImagePath = coverImagePath
        doc.pageIconOffsetX = pageIconOffsetX
        doc.pageIconOffsetY = pageIconOffsetY
        vaultStore.updateDocument(doc)
    }
}

// MARK: - Font warning

struct OWTypographyFontWarningBanner: View {
    var body: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
            OWUnicodeIconView(icon: .warning, size: 14, color: DesignTokens.Color.warning)
            Text(OWTypography.bundledSerifMissingMessage)
                .font(OWTypography.caption)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(DesignTokens.Spacing.spacing2)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DesignTokens.Color.warning.opacity(0.12),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
        )
    }
}

// MARK: - Banner metrics & gradient

enum OWPageBannerMetrics {
    static let stripHeight: CGFloat = 140
    static let iconSize: CGFloat = 52
    static let iconOverlap: CGFloat = 26
}

struct OWPageBannerGradient: View {
    @Environment(\.openWritePalette) private var palette

    var coverStyle: CoverStyle?
    var coverImagePath: String?
    var documentID: UUID?
    var pageType: PageType?
    var stripHeight: CGFloat = OWPageBannerMetrics.stripHeight

    var body: some View {
        ZStack {
            if let coverImage = resolvedCoverImage {
                coverImage
                    .resizable()
                    .scaledToFill()
            } else {
                LinearGradient(
                    colors: gradientColors,
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }
        }
        .frame(height: stripHeight)
        .frame(maxWidth: .infinity)
        .clipped()
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [palette.editorCanvas.opacity(0), palette.editorCanvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 36)
        }
    }

    private var resolvedCoverImage: Image? {
        let vaultRoot = VaultLocationPreferences.resolvedVaultRootURL()
        if let coverImagePath, !coverImagePath.isEmpty {
            let url = VaultCoverStore.resolveURL(relativePath: coverImagePath, vaultRoot: vaultRoot)
            if let nsImage = NSImage(contentsOf: url) {
                return Image(nsImage: nsImage)
            }
        }
        if let documentID,
           let url = VaultCoverStore.fileURL(documentID: documentID, vaultRoot: vaultRoot),
           let nsImage = NSImage(contentsOf: url) {
            return Image(nsImage: nsImage)
        }
        return nil
    }

    private var gradientColors: [Color] {
        if let coverStyle {
            let accent = pageType.map { DesignTokens.ObjectType.accent(for: $0) } ?? DesignTokens.Color.accent
            return coverStyle.gradientColors(fallbackAccent: accent)
        }
        let accent = pageType.map { DesignTokens.ObjectType.accent(for: $0) } ?? DesignTokens.Color.accent
        return [
            accent.opacity(0.42),
            accent.opacity(0.18),
            palette.editorCanvas.opacity(0.05)
        ]
    }
}

// MARK: - Cover picker sheet

struct OWCoverStylePickerSheet: View {
    let documentID: UUID
    @Binding var selection: CoverStyle?
    @Binding var coverImagePath: String?
    var onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss

    @State private var importError: String?

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

  private var hasCustomImage: Bool {
        if let coverImagePath, !coverImagePath.isEmpty { return true }
        let root = VaultLocationPreferences.resolvedVaultRootURL()
        return VaultCoverStore.fileURL(documentID: documentID, vaultRoot: root) != nil
    }

    var body: some View {
        OWSettingsSheet(title: "Cover", onDone: { dismiss() }) {
            ScrollView {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing4) {
                    customImageSection

                    if let importError {
                        Text(importError)
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.danger)
                    }

                    coverSection(title: "Gradients", styles: CoverStyle.gradientPresets)
                    coverSection(title: "Solids", styles: CoverStyle.solidPresets)
                }
                .padding(DesignTokens.Spacing.spacing4)
            }
        }
        .frame(minWidth: 380, minHeight: 360)
    }

    private var customImageSection: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            Text("Custom")
                .font(DesignTokens.Typography.captionEmphasis)
                .foregroundStyle(DesignTokens.Color.textSecondary)

            HStack(spacing: DesignTokens.Spacing.spacing2) {
                Button("Choose image…") {
                    chooseCoverImage()
                }
                .buttonStyle(OWSecondaryRectButtonStyle())

                if hasCustomImage {
                    Button("Remove image", role: .destructive) {
                        clearCustomCover()
                    }
                    .buttonStyle(OWSecondaryRectButtonStyle())
                }
            }

            LazyVGrid(columns: columns, spacing: 12) {
                coverCell(
                    label: "None",
                    colors: [DesignTokens.Color.surface, DesignTokens.Color.surfaceElevated],
                    isSelected: selection == nil && !hasCustomImage
                ) {
                    selection = nil
                    coverImagePath = nil
                    VaultCoverStore.removeCover(
                        documentID: documentID,
                        vaultRoot: VaultLocationPreferences.resolvedVaultRootURL()
                    )
                    onSelect()
                    dismiss()
                }
            }
        }
    }

    private func coverSection(title: String, styles: [CoverStyle]) -> some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            Text(title)
                .font(DesignTokens.Typography.captionEmphasis)
                .foregroundStyle(DesignTokens.Color.textSecondary)

            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(styles) { style in
                    coverCell(
                        label: style.displayName,
                        colors: style.gradientColors(fallbackAccent: DesignTokens.Color.accent),
                        isSelected: selection == style && !hasCustomImage
                    ) {
                        selection = style
                        coverImagePath = nil
                        VaultCoverStore.removeCover(
                            documentID: documentID,
                            vaultRoot: VaultLocationPreferences.resolvedVaultRootURL()
                        )
                        onSelect()
                        dismiss()
                    }
                }
            }
        }
    }

    private func chooseCoverImage() {
        importError = nil
        let panel = NSOpenPanel()
        panel.canChooseFiles = true
        panel.canChooseDirectories = false
        panel.allowsMultipleSelection = false
        panel.allowedContentTypes = VaultCoverStore.openPanelAllowedTypes
        panel.message = "Choose a cover image (PNG, JPEG, or WebP)"

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            let vaultRoot = VaultLocationPreferences.resolvedVaultRootURL()
            let relative = try VaultCoverStore.importCover(
                from: url,
                documentID: documentID,
                vaultRoot: vaultRoot
            )
            coverImagePath = relative
            selection = nil
            onSelect()
            dismiss()
        } catch {
            importError = error.localizedDescription
        }
    }

    private func clearCustomCover() {
        coverImagePath = nil
        VaultCoverStore.removeCover(
            documentID: documentID,
            vaultRoot: VaultLocationPreferences.resolvedVaultRootURL()
        )
        onSelect()
    }

    private func coverCell(
        label: String,
        colors: [Color],
        isSelected: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            VStack(spacing: 6) {
                LinearGradient(colors: colors, startPoint: .topLeading, endPoint: .bottomTrailing)
                    .frame(height: 56)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                            .strokeBorder(
                                isSelected ? DesignTokens.Color.accent : DesignTokens.Color.borderHairline,
                                lineWidth: isSelected ? DesignTokens.Layout.focusRingWidth : DesignTokens.Layout.borderWidth
                            )
                    }
                Text(label)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
    }
}

// MARK: - Page icon picker

private enum OWPageIconPickerRow: Identifiable {
    case sectionHeader(id: String, title: String, isExpanded: Bool)
    case symbolRow(symbols: [String], useSerif: Bool)

    var id: String {
        switch self {
        case .sectionHeader(let id, _, _):
            return "header-\(id)"
        case .symbolRow(let symbols, _):
            return "row-\(symbols.joined())"
        }
    }
}

struct OWPageIconPicker: View {
    let onPick: (String) -> Void

    @State private var tab: OWUnicodeSymbolCatalog.PickerTab = .symbols
    @State private var searchText = ""
    @State private var debouncedSearchText = ""
    @State private var searchDebounceTask: Task<Void, Never>?
    @State private var expandedSectionIDs: Set<String> = []

    private let symbolsPerRow = 8
    private let popoverWidth: CGFloat = 360
    private let scrollHeight: CGFloat = 300

    private var isSearching: Bool {
        !debouncedSearchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var symbolRows: [OWPageIconPickerRow] {
        let sections = OWUnicodeSymbolCatalog.filteredSections(matching: debouncedSearchText)
        var rows: [OWPageIconPickerRow] = []
        rows.reserveCapacity(sections.count * 6)
        for section in sections {
            let isExpanded = isSearching || expandedSectionIDs.contains(section.id)
            rows.append(.sectionHeader(id: section.id, title: section.title, isExpanded: isExpanded))
            guard isExpanded else { continue }
            let useSerif = section.id == "stars" || section.id == "punctuation"
            for chunk in section.symbols.owChunked(into: symbolsPerRow) {
                rows.append(.symbolRow(symbols: chunk, useSerif: useSerif))
            }
        }
        return rows
    }

    private var emojiRows: [OWPageIconPickerRow] {
        let emojis = OWUnicodeSymbolCatalog.filteredEmojis(matching: debouncedSearchText)
        return emojis.owChunked(into: symbolsPerRow).map { .symbolRow(symbols: $0, useSerif: false) }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            Text("Page icon")
                .font(OWTypography.captionEmphasis)
                .foregroundStyle(DesignTokens.Color.textSecondary)

            OWThemedSegmentedControl(
                selection: $tab,
                options: OWUnicodeSymbolCatalog.PickerTab.allCases,
                title: { $0.rawValue }
            )

            searchField

            ScrollView {
                switch tab {
                case .symbols:
                    symbolsContent
                case .emoji:
                    emojiContent
                }
            }
            .frame(height: scrollHeight)
        }
        .frame(width: popoverWidth)
        .onAppear {
            debouncedSearchText = searchText
            if expandedSectionIDs.isEmpty, let first = OWUnicodeSymbolCatalog.sections.first {
                expandedSectionIDs = [first.id]
            }
        }
        .onChange(of: searchText) { _, newValue in
            scheduleSearchDebounce(newValue)
        }
        .onChange(of: debouncedSearchText) { _, newValue in
            if newValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if expandedSectionIDs.isEmpty, let first = OWUnicodeSymbolCatalog.sections.first {
                    expandedSectionIDs = [first.id]
                }
            } else {
                expandedSectionIDs = Set(
                    OWUnicodeSymbolCatalog.filteredSections(matching: newValue).map(\.id)
                )
            }
        }
        .onChange(of: tab) { _, _ in
            searchDebounceTask?.cancel()
            debouncedSearchText = searchText
        }
        .onDisappear {
            searchDebounceTask?.cancel()
        }
    }

    private var searchField: some View {
        HStack(spacing: DesignTokens.Spacing.spacing1) {
            Text("⌕")
                .font(.system(size: 14))
                .foregroundStyle(DesignTokens.Color.textTertiary)
            TextField(tab == .symbols ? "Search symbols…" : "Search emoji…", text: $searchText)
                .textFieldStyle(.plain)
                .font(OWTypography.caption)
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .fill(DesignTokens.Color.surface)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
        }
    }

    @ViewBuilder
    private var symbolsContent: some View {
        if symbolRows.isEmpty {
            emptyState("No symbols match your search.")
        } else {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                ForEach(symbolRows) { row in
                    switch row {
                    case .sectionHeader(let sectionID, let title, let isExpanded):
                        sectionHeaderRow(sectionID: sectionID, title: title, isExpanded: isExpanded)
                    case .symbolRow(let symbols, let useSerif):
                        symbolRowGrid(symbols, useSerif: useSerif)
                    }
                }
            }
            .padding(.bottom, DesignTokens.Spacing.spacing1)
        }
    }

    @ViewBuilder
    private var emojiContent: some View {
        if emojiRows.isEmpty {
            emptyState("No emoji match your search.")
        } else {
            LazyVStack(alignment: .leading, spacing: 4) {
                ForEach(emojiRows) { row in
                    if case .symbolRow(let symbols, let useSerif) = row {
                        symbolRowGrid(symbols, useSerif: useSerif)
                    }
                }
            }
            .padding(.bottom, DesignTokens.Spacing.spacing1)
        }
    }

    private func sectionHeaderRow(sectionID: String, title: String, isExpanded: Bool) -> some View {
        Button {
            withAnimation(DesignTokens.Motion.animationFast) {
                if isExpanded {
                    expandedSectionIDs.remove(sectionID)
                } else {
                    expandedSectionIDs.insert(sectionID)
                }
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.spacing1) {
                OWUnicodeIconView(
                    icon: isExpanded ? .chevronDown : .chevronRight,
                    size: 10,
                    color: DesignTokens.Color.textTertiary
                )
                Text(title)
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                Spacer(minLength: 0)
            }
            .padding(.top, 2)
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
    }

    private func symbolRowGrid(_ symbols: [String], useSerif: Bool) -> some View {
        HStack(spacing: 4) {
            ForEach(symbols, id: \.self) { symbol in
                symbolCell(symbol, useSerif: useSerif)
            }
            if symbols.count < symbolsPerRow {
                ForEach(0 ..< (symbolsPerRow - symbols.count), id: \.self) { _ in
                    Color.clear.frame(width: 32, height: 32)
                }
            }
        }
    }

    private func symbolCell(_ symbol: String, useSerif: Bool) -> some View {
        Button {
            onPick(symbol)
        } label: {
            Text(symbol)
                .font(cellFont(useSerif: useSerif))
                .frame(width: 32, height: 32)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(DesignTokens.Color.surface)
                )
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .accessibilityLabel("Icon \(symbol)")
    }

    private func cellFont(useSerif: Bool) -> Font {
        if useSerif, OWTypography.isBundledSerifAvailable {
            return OWTypography.sized(weight: .regular, pointSize: 20, relativeTo: .title3)
        }
        return .system(size: 22)
    }

    private func scheduleSearchDebounce(_ value: String) {
        searchDebounceTask?.cancel()
        searchDebounceTask = Task {
            try? await Task.sleep(for: .milliseconds(180))
            guard !Task.isCancelled else { return }
            await MainActor.run {
                debouncedSearchText = value
            }
        }
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(OWTypography.caption)
            .foregroundStyle(DesignTokens.Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, DesignTokens.Spacing.spacing3)
    }
}

private extension Array {
    func owChunked(into size: Int) -> [[Element]] {
        guard size > 0, !isEmpty else { return [] }
        return stride(from: 0, to: count, by: size).map { start in
            Array(self[start ..< Swift.min(start + size, count)])
        }
    }
}

/// Legacy name — redirects to `OWPageIconPicker`.
typealias OWEmojiPickerGrid = OWPageIconPicker
