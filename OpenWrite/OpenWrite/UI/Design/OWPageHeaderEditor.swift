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
    @Binding var pageIconOffsetX: CGFloat
    @Binding var pageIconOffsetY: CGFloat
    @ViewBuilder var metadata: () -> Metadata

    @State private var showCoverPicker = false
    @State private var showDescriptionField = false
    @State private var descriptionText = ""
    @State private var showEmojiPicker = false
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
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.bottom, DesignTokens.Spacing.spacing2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .onAppear { syncDescriptionFromDocument() }
        .onChange(of: documentID) { _, _ in syncDescriptionFromDocument() }
        .sheet(isPresented: $showCoverPicker) {
            OWCoverStylePickerSheet(selection: $coverStyle) {
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
                    pageType: document?.pageType,
                    stripHeight: OWPageBannerMetrics.stripHeight
                )
            }
            .buttonStyle(.plain)
            .help("Change cover")

            pageIconChip
                .padding(.leading, DesignTokens.Spacing.spacing3 + pageIconOffsetX)
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
        Menu {
            Button("Change cover…") {
                showCoverPicker = true
            }
            Button(showDescriptionField ? "Hide description" : "Add description") {
                withAnimation(.easeOut(duration: 0.18)) {
                    showDescriptionField.toggle()
                    if showDescriptionField, descriptionText.isEmpty {
                        syncDescriptionFromDocument()
                    }
                }
            }
            Button("Change icon…") {
                showEmojiPicker = true
            }
            Divider()
            Button("Reset icon position") {
                pageIconOffsetX = 0
                pageIconOffsetY = 0
                commitHeaderFields()
            }
            Button("Remove cover", role: .destructive) {
                coverStyle = nil
                commitHeaderFields()
            }
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
        .menuStyle(.borderlessButton)
        .fixedSize()
        .help("Page options")
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
    var pageType: PageType?
    var stripHeight: CGFloat = OWPageBannerMetrics.stripHeight

    var body: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .frame(height: stripHeight)
        .frame(maxWidth: .infinity)
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [palette.editorCanvas.opacity(0), palette.editorCanvas],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 36)
        }
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
    @Binding var selection: CoverStyle?
    var onSelect: () -> Void
    @Environment(\.dismiss) private var dismiss

    private let columns = Array(repeating: GridItem(.flexible(), spacing: 12), count: 4)

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    coverCell(label: "None", colors: [DesignTokens.Color.surface, DesignTokens.Color.surfaceElevated], isSelected: selection == nil) {
                        selection = nil
                        onSelect()
                        dismiss()
                    }

                    ForEach(CoverStyle.allCases) { style in
                        coverCell(
                            label: style.displayName,
                            colors: style.gradientColors(fallbackAccent: DesignTokens.Color.accent),
                            isSelected: selection == style
                        ) {
                            selection = style
                            onSelect()
                            dismiss()
                        }
                    }
                }
                .padding()
            }
            .navigationTitle("Cover")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                        .buttonStyle(OWToolbarActionButtonStyle(isEnabled: true))
                }
            }
        }
        .frame(minWidth: 360, minHeight: 280)
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
                            .strokeBorder(isSelected ? DesignTokens.Color.accent : DesignTokens.Color.borderHairline, lineWidth: isSelected ? 2 : 0.5)
                    }
                Text(label)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Page icon picker

struct OWPageIconPicker: View {
    let onPick: (String) -> Void

    @State private var tab: OWUnicodeSymbolCatalog.PickerTab = .symbols
    @State private var searchText = ""

    private let columns = Array(repeating: GridItem(.fixed(36), spacing: 4), count: 8)
    private let popoverWidth: CGFloat = 360
    private let scrollHeight: CGFloat = 300

    private var filteredSections: [OWUnicodeSymbolCatalog.Section] {
        OWUnicodeSymbolCatalog.filteredSections(matching: searchText)
    }

    private var filteredEmojis: [String] {
        OWUnicodeSymbolCatalog.filteredEmojis(matching: searchText)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            Text("Page icon")
                .font(OWTypography.captionEmphasis)
                .foregroundStyle(DesignTokens.Color.textSecondary)

            Picker("Kind", selection: $tab) {
                ForEach(OWUnicodeSymbolCatalog.PickerTab.allCases) { pickerTab in
                    Text(pickerTab.rawValue).tag(pickerTab)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

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
    }

    private var searchField: some View {
        HStack(spacing: DesignTokens.Spacing.spacing1) {
            Text("⌕")
                .font(.system(size: 14))
                .foregroundStyle(DesignTokens.Color.textTertiary)
            TextField("Search symbols…", text: $searchText)
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
                .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: 0.5)
        }
    }

    @ViewBuilder
    private var symbolsContent: some View {
        if filteredSections.isEmpty {
            emptyState("No symbols match your search.")
        } else {
            LazyVStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                ForEach(filteredSections) { section in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(section.title)
                            .font(OWTypography.caption)
                            .foregroundStyle(DesignTokens.Color.textTertiary)

                        LazyVGrid(columns: columns, spacing: 4) {
                            ForEach(section.symbols, id: \.self) { symbol in
                                symbolCell(symbol, useSerif: section.id == "stars" || section.id == "punctuation")
                            }
                        }
                    }
                }
            }
            .padding(.bottom, DesignTokens.Spacing.spacing1)
        }
    }

    @ViewBuilder
    private var emojiContent: some View {
        if filteredEmojis.isEmpty {
            emptyState("No emoji match your search.")
        } else {
            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(filteredEmojis, id: \.self) { emoji in
                    symbolCell(emoji, useSerif: false)
                }
            }
            .padding(.bottom, DesignTokens.Spacing.spacing1)
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
        .accessibilityLabel("Icon \(symbol)")
    }

    private func cellFont(useSerif: Bool) -> Font {
        if useSerif, OWTypography.isBundledSerifAvailable {
            return OWTypography.sized(weight: .regular, pointSize: 20, relativeTo: .title3)
        }
        return .system(size: 22)
    }

    private func emptyState(_ message: String) -> some View {
        Text(message)
            .font(OWTypography.caption)
            .foregroundStyle(DesignTokens.Color.textTertiary)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, DesignTokens.Spacing.spacing3)
    }
}

/// Legacy name — redirects to `OWPageIconPicker`.
typealias OWEmojiPickerGrid = OWPageIconPicker
