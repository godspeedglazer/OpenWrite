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
    @State private var showMoreMenu = false
    @State private var dragBaseOffset = CGSize.zero

    private var document: VaultDocument? {
        vaultStore.documents.first { $0.id == documentID }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            bannerSection

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                if !OWTypography.isBundledSerifAvailable {
                    OWTypographyFontWarningBanner()
                }

                headerToolbar

                titleField

                if showDescriptionField {
                    descriptionField
                }

                metadata()
            }
            .openWriteEditorContentWidth()
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
        .popover(isPresented: $showEmojiPicker, arrowEdge: .bottom) {
            OWEmojiPickerGrid { emoji in
                pageIcon = emoji
                showEmojiPicker = false
                commitHeaderFields()
            }
            .padding(DesignTokens.Spacing.spacing2)
        }
        .confirmationDialog("Page options", isPresented: $showMoreMenu, titleVisibility: .visible) {
            Button("Reset icon position") {
                pageIconOffsetX = 0
                pageIconOffsetY = 0
                commitHeaderFields()
            }
            Button("Remove cover", role: .destructive) {
                coverStyle = nil
                commitHeaderFields()
            }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Banner

    private var bannerSection: some View {
        ZStack(alignment: .bottomLeading) {
            OWPageBannerGradient(
                coverStyle: coverStyle,
                pageType: document?.pageType,
                stripHeight: OWPageBannerMetrics.stripHeight
            )

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
            ? (document?.resolvedPageIcon ?? "📝")
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

    // MARK: - Toolbar & fields

    private var headerToolbar: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            OWPageHeaderToolbarChip(title: "Cover", icon: .grid) {
                showCoverPicker = true
            }

            OWPageHeaderToolbarChip(
                title: showDescriptionField ? "Hide description" : "Add description",
                icon: .editCompose
            ) {
                withAnimation(.easeOut(duration: 0.18)) {
                    showDescriptionField.toggle()
                    if showDescriptionField, descriptionText.isEmpty {
                        syncDescriptionFromDocument()
                    }
                }
            }

            OWPageHeaderToolbarChip(title: "More", prefix: "⋯") {
                showMoreMenu = true
            }

            Spacer()

            Button("Emoji panel") {
                NSApp.orderFrontCharacterPalette(nil)
            }
            .buttonStyle(.plain)
            .font(OWTypography.caption)
            .foregroundStyle(DesignTokens.Color.textTertiary)
            .help("Open macOS emoji picker")
        }
    }

    private var titleField: some View {
        TextField("Untitled", text: $title, axis: .vertical)
            .font(OWTypography.documentTitle)
            .lineSpacing(OWTypography.documentTitleLineSpacing)
            .foregroundStyle(DesignTokens.Color.textPrimary)
            .textFieldStyle(.plain)
            .lineLimit(1 ... 6)
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

// MARK: - Toolbar chip

private struct OWPageHeaderToolbarChip: View {
    let title: String
    var icon: OWUnicodeIcon?
    var prefix: String?
    let action: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.spacing1) {
                if let prefix {
                    Text(prefix)
                        .font(DesignTokens.Typography.captionEmphasis)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }
                if let icon {
                    OWUnicodeIconView(icon, size: 12, color: DesignTokens.Color.textTertiary)
                }
                Text(title)
                    .font(DesignTokens.Typography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.vertical, DesignTokens.Spacing.spacing2)
            .background(
                RoundedRectangle(cornerRadius: DesignTokens.Radius.metadataChip, style: .continuous)
                    .fill(isHovered ? DesignTokens.Color.selectionPill : DesignTokens.Color.surface.opacity(0.85))
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.metadataChip, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: 0.5)
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
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

// MARK: - Emoji grid

struct OWEmojiPickerGrid: View {
    let onPick: (String) -> Void

    private static let quickPick = [
        "📝", "✅", "📁", "📚", "🔖", "💡", "🎯", "⭐",
        "🌐", "📓", "🗂️", "📄", "🧠", "🔥", "❤️", "🎨"
    ]

    private let columns = Array(repeating: GridItem(.fixed(40), spacing: 4), count: 8)

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            Text("Page icon")
                .font(OWTypography.captionEmphasis)
                .foregroundStyle(DesignTokens.Color.textSecondary)

            LazyVGrid(columns: columns, spacing: 4) {
                ForEach(Self.quickPick, id: \.self) { emoji in
                    Button {
                        onPick(emoji)
                    } label: {
                        Text(emoji)
                            .font(.system(size: 22))
                            .frame(width: 36, height: 36)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(DesignTokens.Color.surface)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(width: 340)
    }
}
