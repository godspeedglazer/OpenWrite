import AppKit
import SwiftUI

// MARK: - OWPreviewBlockRow

/// Filled block-style preview row for rendered note content (Anytype-inspired density, clean-room).
struct OWPreviewBlockRow: View {
    let block: NoteBlock
    var text: Binding<String>? = nil
    var blockAttributes: Binding<[String: String]>? = nil
    var checked: Binding<Bool>? = nil
    var language: Binding<String>? = nil
    var calloutType: Binding<String>? = nil
    var onSelectionChange: ((String?) -> Void)? = nil
    var onRefinePreset: ((InlineRefinePreset, String) -> Void)? = nil
    var previewMode: Bool = false
    var onActivate: (() -> Void)? = nil

    @Environment(\.openWritePalette) private var palette
    @Environment(ThemeManager.self) private var themeManager
    @Environment(\.blockFormatting) private var blockFormatting
    @EnvironmentObject private var vaultStore: VaultStore
    @EnvironmentObject private var workbench: WorkbenchState

    private var isEditing: Bool { text != nil }

    var body: some View {
        Group {
            switch block.kind {
            case .heading1, .heading2, .heading3:
                headingRow
            case .divider:
                Divider()
                    .padding(.vertical, DesignTokens.Spacing.spacing1)
            case .quote:
                quoteRow
            case .callout:
                calloutRow
            case .code:
                codeRow
            case .bullet:
                bulletRow
            case .todo:
                todoRow
            case .wikilink:
                linkRow
            case .property:
                propertyRow
            case .paragraph:
                paragraphRow
            case .image:
                imageRow
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            guard previewMode else { return }
            onActivate?()
        }
    }

    private var headingRow: some View {
        inlineText(
            font: headingFont,
            lineSpacing: headingLineSpacing,
            foreground: DesignTokens.Color.textPrimary
        )
            .frame(maxWidth: .infinity, alignment: .leading)
            .owBlockCardPadding()
            .background(blockFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var paragraphRow: some View {
        inlineText(
            font: DesignTokens.Typography.body,
            lineSpacing: DesignTokens.Typography.bodyLineSpacing,
            foreground: DesignTokens.Color.textPrimary
        )
            .frame(maxWidth: .infinity, alignment: .leading)
            .owBlockCardPadding()
            .background(blockFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var bulletRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
            Text("•")
                .font(DesignTokens.Typography.bodyEmphasis)
                .foregroundStyle(DesignTokens.Color.textSecondary)
            inlineText(
                font: DesignTokens.Typography.body,
                lineSpacing: DesignTokens.Typography.bodyLineSpacing,
                foreground: DesignTokens.Color.textPrimary
            )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .owBlockListCardPadding()
        .background(blockFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var todoRow: some View {
        HStack(alignment: .center, spacing: DesignTokens.Spacing.spacing2) {
            todoCheckbox
            inlineText(
                font: DesignTokens.Typography.body,
                lineSpacing: DesignTokens.Typography.bodyLineSpacing,
                foreground: isTodoChecked ? DesignTokens.Color.textSecondary : DesignTokens.Color.textPrimary,
                strikethrough: isTodoChecked
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .owBlockListCardPadding()
        .background(blockFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    @ViewBuilder
    private var todoCheckbox: some View {
        let filled = isTodoChecked
        if let checked {
            Button {
                checked.wrappedValue.toggle()
            } label: {
                todoCheckboxGlyph(filled: checked.wrappedValue)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .openWriteFocusChrome()
            .contentShape(Rectangle())
        } else {
            todoCheckboxGlyph(filled: filled)
        }
    }

    private func todoCheckboxGlyph(filled: Bool) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .strokeBorder(DesignTokens.Color.textTertiary.opacity(0.55), lineWidth: 1.5)
                .frame(width: 18, height: 18)
            if filled {
                OWUnicodeIconView(icon: .checkmark, size: 12, color: DesignTokens.Color.accent)
            }
        }
    }

    private var isTodoChecked: Bool {
        if let checked { return checked.wrappedValue }
        return block.isChecked
    }

    private var calloutRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing1) {
            calloutLeading
                .frame(width: DesignTokens.Layout.calloutLeadingGutter, alignment: .leading)
            inlineText(
                font: DesignTokens.Typography.body,
                lineSpacing: DesignTokens.Typography.bodyLineSpacing,
                foreground: DesignTokens.Color.textPrimary
            )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .owBlockCardPadding()
        .background(calloutFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .strokeBorder(calloutAccent.opacity(0.22), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var calloutLeading: some View {
        if let calloutType, isEditing {
            OWThemedDropdown(
                accessibilityLabel: "Callout type",
                selection: calloutType,
                options: Self.calloutVariants,
                optionTitle: { $0.capitalized },
                compact: true,
                leadingIcon: calloutIcon,
                leadingIconColor: calloutAccent,
                iconOnly: true
            )
            .padding(.top, 2)
        } else {
            OWUnicodeIconView(icon: calloutIcon, size: 16, color: calloutAccent)
                .padding(.top, 2)
        }
    }

    private static let calloutVariants = ["note", "tip", "warning", "important", "danger"]

    private var quoteRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(DesignTokens.Color.accent.opacity(0.55))
                .frame(width: DesignTokens.Layout.quoteBarWidth)
            inlineText(font: DesignTokens.Typography.callout, foreground: DesignTokens.Color.textSecondary)
                .italic(!isEditing)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .owBlockCardPadding()
        .background(blockFill.opacity(0.85), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var codeRow: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            HStack(spacing: DesignTokens.Spacing.spacing2) {
                Text("⌘")
                    .font(DesignTokens.Typography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                if isEditing, let language {
                    TextField("language", text: language)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.captionEmphasis)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                        .frame(maxWidth: 120)
                } else {
                    Text(resolvedLanguageLabel)
                        .font(DesignTokens.Typography.captionEmphasis)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }
                Spacer(minLength: 0)
            }
            Group {
                if isEditing, let text {
                    TextField("Code snippet", text: text, axis: .vertical)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.code)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text(block.text)
                        .font(DesignTokens.Typography.code)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .owBlockCardPadding()
        .background(DesignTokens.Color.codeBackground, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: 1)
        }
    }

    private var resolvedLanguageLabel: String {
        let lang = language?.wrappedValue ?? block.attributes["language"] ?? ""
        return lang.isEmpty ? "code" : lang
    }

    private var linkRow: some View {
        Group {
            if isEditing, let text {
                linkRowContent {
                    TextField("Link title", text: text)
                        .textFieldStyle(.plain)
                        .font(DesignTokens.Typography.bodyEmphasis)
                        .foregroundStyle(DesignTokens.Color.wikilink)
                }
            } else {
                Button {
                    openWikilinkTarget(named: block.text)
                } label: {
                    linkRowContent {
                        Text(block.text)
                            .font(DesignTokens.Typography.bodyEmphasis)
                            .foregroundStyle(DesignTokens.Color.wikilink)
                    }
                }
                .buttonStyle(.plain)
                .openWriteFocusChrome()
                .help("Open linked page")
            }
        }
    }

    private func linkRowContent<Label: View>(@ViewBuilder label: () -> Label) -> some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            OWUnicodeIconView(icon: .link, size: 14, color: DesignTokens.Color.wikilink)
            label()
        }
        .owBlockCardPadding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            DesignTokens.Color.wikilink.opacity(0.08),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
        )
    }

    private func openWikilinkTarget(named title: String) {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let match = vaultStore.documentsInActiveVault.first {
            $0.displayTitle.compare(trimmed, options: [.caseInsensitive, .diacriticInsensitive]) == .orderedSame
        }
        if let match {
            vaultStore.selectedDocumentID = match.id
            workbench.showEditor()
        }
    }

    private var isImagePending: Bool {
        block.attributes[ImagePasteSupport.pendingAttributeKey] == "true"
    }

    private var imageRow: some View {
        Group {
            if isImagePending {
                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    ProgressView()
                        .controlSize(.small)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Adding image…")
                            .font(DesignTokens.Typography.captionEmphasis)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                        Text("Paste with ⌘V or drop an image file onto the note.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let url = VaultAttachmentStore.resolveFileURL(for: block),
                      let nsImage = NSImage(contentsOf: url) {
                ImageBlockCopyView(block: block, image: nsImage)
                    .frame(maxWidth: .infinity, maxHeight: 360, alignment: .leading)
            } else {
                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    OWUnicodeIconView(icon: .missingNote, size: 16, color: DesignTokens.Color.textTertiary)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(block.text.isEmpty ? "Image unavailable" : block.text)
                            .font(DesignTokens.Typography.captionEmphasis)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                        Text("Paste with ⌘V or drop an image file onto the note.")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.textTertiary.opacity(0.85))
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .owBlockCardPadding()
        .background(blockFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
        .accessibilityLabel(block.text.isEmpty ? "Image" : block.text)
    }

    private var propertyRow: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            Text(block.propertyKey?.displayName ?? block.text)
                .font(DesignTokens.Typography.captionEmphasis)
                .foregroundStyle(DesignTokens.Color.textTertiary)
            Text(block.propertyValuePayload)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textPrimary)
        }
        .padding(.trailing, DesignTokens.Spacing.spacing3)
        .padding(.vertical, DesignTokens.Spacing.spacing2)
        .background(DesignTokens.Color.surfaceElevated, in: Capsule())
    }

    @ViewBuilder
    private func inlineText(
        font: Font,
        lineSpacing: CGFloat = 0,
        foreground: Color,
        strikethrough: Bool = false
    ) -> some View {
        if let text, let blockAttributes, !previewMode {
            OWBlockTextEditor(
                markdown: text,
                blockAttributes: blockAttributes,
                blockID: block.id,
                baseSwiftUIFont: font,
                basePointSize: inlineBasePointSize(for: font),
                textColor: foreground,
                selectionHighlight: palette.selectionHighlight,
                selectionForeground: palette.textPrimary,
                themeRevision: themeManager.selectedTheme.rawValue,
                formatting: blockFormatting,
                strikethrough: strikethrough,
                onSelectionChange: onSelectionChange,
                onRefinePreset: onRefinePreset
            )
            .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(formattedPreview)
                .font(font)
                .lineSpacing(lineSpacing)
                .foregroundStyle(foreground)
                .strikethrough(strikethrough)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var formattedPreview: AttributedString {
        let family = InlineMarkdown.FontFamily(attribute: block.attributes["fontFamily"])
        let size = block.attributes["fontSize"].flatMap { Int($0) }.flatMap { $0 > 0 ? CGFloat($0) : nil }
        let ns = InlineMarkdown.attributedString(
            from: block.text,
            family: family,
            pointSize: size,
            textColor: NSColor(palette.textPrimary)
        )
        return AttributedString(ns)
    }

    private var blockFill: Color {
        DesignTokens.Color.surface
    }

    private var calloutVariant: String {
        let bound = calloutType?.wrappedValue ?? block.attributes["callout"] ?? "note"
        return bound.isEmpty ? "note" : bound
    }

    private var calloutAccent: Color {
        switch calloutVariant.lowercased() {
        case "warning", "important":
            return DesignTokens.Color.warning
        case "tip":
            return DesignTokens.Color.success
        case "danger":
            return DesignTokens.Color.danger
        default:
            return DesignTokens.Color.accent
        }
    }

    private var calloutFill: Color {
        calloutAccent.opacity(0.14)
    }

    private var calloutIcon: OWIcon {
        switch calloutVariant.lowercased() {
        case "warning", "important", "danger":
            return .warning
        case "tip":
            return .sparkles
        default:
            return .note
        }
    }

    private var headingFont: Font {
        switch block.kind {
        case .heading1: return DesignTokens.Typography.heading1
        case .heading2: return DesignTokens.Typography.heading2
        case .heading3: return DesignTokens.Typography.heading3
        default: return DesignTokens.Typography.body
        }
    }

    private var headingLineSpacing: CGFloat {
        switch block.kind {
        case .heading1: return DesignTokens.Typography.heading1LineSpacing
        case .heading2: return DesignTokens.Typography.heading2LineSpacing
        case .heading3: return DesignTokens.Typography.heading3LineSpacing
        default: return 0
        }
    }

    private func inlineBasePointSize(for font: Font) -> CGFloat {
        switch block.kind {
        case .heading1: return OWTypography.Scale.heading1
        case .heading2: return OWTypography.Scale.heading2
        case .heading3: return OWTypography.Scale.heading3
        default: return OWTypography.Scale.body
        }
    }
}

// MARK: - Block card padding

private extension View {
    /// Inner card breathing room; pairs with `openWriteEditorLeadingInset` on the block column.
    func owBlockCardPadding() -> some View {
        padding(.top, DesignTokens.Spacing.spacing2)
            .padding(.bottom, DesignTokens.Spacing.spacing2)
            .padding(.leading, DesignTokens.Spacing.spacing3)
            .padding(.trailing, DesignTokens.Spacing.spacing3)
    }

    /// List blocks need slightly more leading inset so markers are not clipped by the card edge.
    func owBlockListCardPadding() -> some View {
        owBlockCardPadding()
            .padding(.leading, DesignTokens.Layout.blockCardListExtraLeadingInset)
    }
}

// MARK: - Image copy to pasteboard

private struct ImageBlockCopyView: NSViewRepresentable {
    let block: NoteBlock
    let image: NSImage

    func makeNSView(context: Context) -> ImageCopyContainerView {
        let view = ImageCopyContainerView()
        view.openWriteSuppressFocusRing()
        view.configure(block: block, image: image)
        return view
    }

    func updateNSView(_ nsView: ImageCopyContainerView, context: Context) {
        nsView.configure(block: block, image: image)
    }
}

private final class ImageCopyContainerView: NSView {
    private let imageView = NSImageView()
    var block: NoteBlock?

    override var acceptsFirstResponder: Bool { true }

    func configure(block: NoteBlock, image: NSImage) {
        self.block = block
        imageView.image = image
        imageView.imageScaling = .scaleProportionallyUpOrDown
        needsLayout = true
    }

    override func layout() {
        super.layout()
        imageView.frame = bounds
    }

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if imageView.superview == nil {
            addSubview(imageView)
        }
    }

    @objc func copy(_ sender: Any?) {
        if let block, ImagePasteSupport.copyImageToPasteboard(for: block) {
            return
        }
    }
}
