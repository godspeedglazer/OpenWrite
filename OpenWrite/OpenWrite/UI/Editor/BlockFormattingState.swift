import AppKit
import SwiftUI

/// Tracks the focused block editor and applies formatting to the active `NSTextView`.
final class BlockFormattingState: ObservableObject {
    @Published private(set) var focusedBlockID: UUID?
    @Published private(set) var hasEditableText = false
    @Published private(set) var formatState = InlineMarkdown.FormatState()

    private weak var activeTextView: NSTextView?
    private var onMarkdownChange: ((String) -> Void)?

    var canApplyFormatting: Bool {
        focusedBlockID != nil && activeTextView != nil && hasEditableText
    }

    /// Call when leaving preview or tearing down the block host so stale `NSTextView` refs are not used.
    func clearActiveEditor() {
        activeTextView = nil
        focusedBlockID = nil
        hasEditableText = false
        formatState = InlineMarkdown.FormatState()
        onMarkdownChange = nil
    }

    func register(
        textView: NSTextView,
        blockID: UUID,
        onMarkdownChange: @escaping (String) -> Void
    ) {
        activeTextView = textView
        self.onMarkdownChange = onMarkdownChange
        focusedBlockID = blockID
        refreshSelectionState(textView)
    }

    func refreshSelectionState(_ textView: NSTextView) {
        guard activeTextView === textView else { return }
        let inspect = InlineMarkdown.inspectionRange(in: textView)
        hasEditableText = (textView.string as NSString).length > 0
            || inspect.length > 0
        formatState = InlineMarkdown.formatState(in: textView, baseFont: baseFont(for: textView))
    }

    func syncMarkdownFromActiveView() {
        guard let activeTextView, let storage = activeTextView.textStorage else { return }
        onMarkdownChange?(InlineMarkdown.markdown(from: storage))
    }

    /// Selection for Refine — prefers highlighted text, otherwise the focused block body.
    func refineSelectionSnapshot() -> (blockID: UUID, text: String)? {
        guard let textView = activeTextView, let blockID = focusedBlockID else { return nil }
        let range = textView.selectedRange()
        let ns = textView.string as NSString
        if range.length > 0, NSMaxRange(range) <= ns.length {
            let selected = ns.substring(with: range).trimmingCharacters(in: .whitespacesAndNewlines)
            guard !selected.isEmpty else { return nil }
            return (blockID, selected)
        }
        let whole = textView.string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !whole.isEmpty else { return nil }
        return (blockID, whole)
    }

    func toggleBold() { run { InlineMarkdown.toggleBold(in: $0, baseFont: baseFont(for: $0)) } }
    func toggleItalic() { run { InlineMarkdown.toggleItalic(in: $0, baseFont: baseFont(for: $0)) } }
    func toggleUnderline() { run { InlineMarkdown.toggleUnderline(in: $0) } }
    func toggleStrikethrough() { run { InlineMarkdown.toggleStrikethrough(in: $0) } }

    func applyFontFamily(_ family: InlineMarkdown.FontFamily, attributes: Binding<[String: String]>) {
        var updated = attributes.wrappedValue
        updated["fontFamily"] = family.rawValue
        attributes.wrappedValue = updated
        reloadActiveBlock(attributes: updated)
    }

    func applyFontSize(points: CGFloat, attributes: Binding<[String: String]>) {
        var updated = attributes.wrappedValue
        updated["fontSize"] = String(Int(points))
        attributes.wrappedValue = updated
        reloadActiveBlock(attributes: updated)
    }

    private func run(_ work: (NSTextView) -> Void) {
        guard let textView = activeTextView else { return }
        work(textView)
        syncMarkdownFromActiveView()
        refreshSelectionState(textView)
        restoreEditingFocus(textView)
    }

    private func reloadActiveBlock(attributes: [String: String]) {
        guard let activeTextView, let storage = activeTextView.textStorage else { return }
        let selection = activeTextView.selectedRange()
        let markdown = InlineMarkdown.markdown(from: storage)
        let family = InlineMarkdown.FontFamily(attribute: attributes["fontFamily"])
        let size = attributes["fontSize"].flatMap { Int($0) }.flatMap { $0 > 0 ? CGFloat($0) : nil }
        let color = (storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor)
            ?? NSColor(ThemeManager.shared.palette.textPrimary)
        activeTextView.undoManager?.disableUndoRegistration()
        storage.setAttributedString(
            InlineMarkdown.attributedString(
                from: markdown,
                family: family,
                pointSize: size,
                textColor: color,
                linkColor: NSColor(DesignTokens.Color.accent)
            )
        )
        activeTextView.undoManager?.enableUndoRegistration()
        let length = (activeTextView.string as NSString).length
        if length > 0 {
            let safeLocation = min(selection.location, max(length - 1, 0))
            let safeLength = min(selection.length, length - safeLocation)
            activeTextView.setSelectedRange(NSRange(location: safeLocation, length: safeLength))
        }
        onMarkdownChange?(markdown)
        refreshSelectionState(activeTextView)
        restoreEditingFocus(activeTextView)
    }

    private func restoreEditingFocus(_ textView: NSTextView) {
        guard textView.window?.firstResponder !== textView else { return }
        textView.window?.makeFirstResponder(textView)
    }

    private func baseFont(for textView: NSTextView) -> NSFont {
        if let font = textView.typingAttributes[.font] as? NSFont { return font }
        return InlineMarkdown.baseNSFont(family: nil, pointSize: nil)
    }
}

// MARK: - Toolbar

struct OWBlockFormattingToolbar: View {
    @ObservedObject var formatting: BlockFormattingState
    @Binding var blockAttributes: [String: String]
    @Binding var isPreviewMode: Bool

    private let fontSizes: [CGFloat] = [12, 14, 16, 18, 20, 24]

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            formatButton("B", help: "Bold", isActive: formatting.formatState.isBold) {
                formatting.toggleBold()
            }
            formatButton("I", help: "Italic", isActive: formatting.formatState.isItalic) {
                formatting.toggleItalic()
            }
            formatButton("U", help: "Underline", isActive: formatting.formatState.isUnderline) {
                formatting.toggleUnderline()
            }
            formatButton("S", help: "Strikethrough", isActive: formatting.formatState.isStrikethrough) {
                formatting.toggleStrikethrough()
            }

            Divider().frame(height: 18)

            OWThemedDropdown(
                accessibilityLabel: "Font family",
                selection: fontFamilyBinding,
                options: [InlineMarkdown.FontFamily.serif, .sans],
                optionTitle: { $0 == .serif ? "Serif" : "Sans" },
                minWidth: 72,
                compact: true
            )
            .disabled(!formatting.canApplyFormatting)

            OWThemedDropdown(
                accessibilityLabel: "Font size",
                selection: fontSizeBinding,
                options: fontSizes,
                optionTitle: { "\(Int($0))" },
                minWidth: 52,
                compact: true
            )
            .disabled(!formatting.canApplyFormatting)

            Spacer(minLength: DesignTokens.Spacing.spacing2)

            Button {
                isPreviewMode.toggle()
            } label: {
                Text(isPreviewMode ? "Edit" : "Preview")
                    .font(OWTypography.captionEmphasis)
                    .foregroundStyle(
                        isPreviewMode ? DesignTokens.Color.accent : DesignTokens.Color.textSecondary
                    )
                    .padding(.horizontal, DesignTokens.Spacing.spacing2)
                    .padding(.vertical, 6)
                    .background(
                        isPreviewMode
                            ? DesignTokens.Color.accent.opacity(0.18)
                            : DesignTokens.Color.surfaceElevated.opacity(0.9),
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                    )
            }
            .buttonStyle(.plain)
            .openWriteFocusChrome()
            .help(isPreviewMode ? "Return to editing" : "Hide editing chrome and show rendered blocks")
        }
        .font(OWTypography.captionEmphasis)
        .foregroundStyle(DesignTokens.Color.textSecondary)
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .padding(.vertical, DesignTokens.Spacing.spacing1)
        .background(
            DesignTokens.Color.editorCanvas,
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: DesignTokens.Layout.borderWidth)
        }
        .focusable(false)
        .opacity(1)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var fontFamilyBinding: Binding<InlineMarkdown.FontFamily> {
        Binding(
            get: { InlineMarkdown.FontFamily(attribute: blockAttributes["fontFamily"]) ?? .serif },
            set: { formatting.applyFontFamily($0, attributes: $blockAttributes) }
        )
    }

    private var fontSizeBinding: Binding<CGFloat> {
        Binding(
            get: {
                if let raw = blockAttributes["fontSize"], let value = Int(raw), value > 0 {
                    return CGFloat(value)
                }
                return OWTypography.Scale.body
            },
            set: { formatting.applyFontSize(points: $0, attributes: $blockAttributes) }
        )
    }

    private func formatButton(
        _ title: String,
        help: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Text(title)
                .frame(minWidth: 26, minHeight: 26)
                .background(
                    isActive
                        ? DesignTokens.Color.accent.opacity(0.22)
                        : DesignTokens.Color.surfaceElevated.opacity(0.9),
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                )
                .foregroundStyle(isActive ? DesignTokens.Color.accent : DesignTokens.Color.textSecondary)
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .help(help)
        .disabled(!formatting.canApplyFormatting)
    }
}

private struct BlockFormattingKey: EnvironmentKey {
    static let defaultValue = BlockFormattingState()
}

extension EnvironmentValues {
    var blockFormatting: BlockFormattingState {
        get { self[BlockFormattingKey.self] }
        set { self[BlockFormattingKey.self] = newValue }
    }
}
