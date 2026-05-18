import AppKit
import SwiftUI

/// Tracks the focused block editor and applies formatting to the active `NSTextView`.
final class BlockFormattingState: ObservableObject {
    @Published private(set) var focusedBlockID: UUID?
    @Published private(set) var hasSelection = false

    private weak var activeTextView: NSTextView?
    private var onMarkdownChange: ((String) -> Void)?

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

    func resign(textView: NSTextView) {
        guard activeTextView === textView else { return }
        activeTextView = nil
        onMarkdownChange = nil
        focusedBlockID = nil
        hasSelection = false
    }

    func refreshSelectionState(_ textView: NSTextView) {
        guard activeTextView === textView else { return }
        hasSelection = InlineMarkdown.selectionOrAll(in: textView).length > 0
    }

    func syncMarkdownFromActiveView() {
        guard let activeTextView, let storage = activeTextView.textStorage else { return }
        onMarkdownChange?(InlineMarkdown.markdown(from: storage))
    }

    func toggleBold() { run { InlineMarkdown.toggleBold(in: $0, baseFont: baseFont(for: $0)) } }
    func toggleItalic() { run { InlineMarkdown.toggleItalic(in: $0, baseFont: baseFont(for: $0)) } }
    func toggleUnderline() { run { InlineMarkdown.toggleUnderline(in: $0) } }
    func toggleStrikethrough() { run { InlineMarkdown.toggleStrikethrough(in: $0) } }

    func applyFontFamily(_ family: InlineMarkdown.FontFamily, attributes: Binding<[String: String]>) {
        attributes.wrappedValue["fontFamily"] = family.rawValue
        reloadActiveBlock(attributes: attributes.wrappedValue)
    }

    func applyFontSize(points: CGFloat, attributes: Binding<[String: String]>) {
        attributes.wrappedValue["fontSize"] = String(Int(points))
        reloadActiveBlock(attributes: attributes.wrappedValue)
    }

    private func run(_ work: (NSTextView) -> Void) {
        guard let textView = activeTextView else { return }
        work(textView)
        syncMarkdownFromActiveView()
        refreshSelectionState(textView)
    }

    private func reloadActiveBlock(attributes: [String: String]) {
        guard let activeTextView, let storage = activeTextView.textStorage else { return }
        let markdown = InlineMarkdown.markdown(from: storage)
        let family = InlineMarkdown.FontFamily(attribute: attributes["fontFamily"])
        let size = attributes["fontSize"].flatMap { Int($0) }.flatMap { $0 > 0 ? CGFloat($0) : nil }
        let color = (storage.attribute(.foregroundColor, at: 0, effectiveRange: nil) as? NSColor) ?? .labelColor
        storage.setAttributedString(
            InlineMarkdown.attributedString(from: markdown, family: family, pointSize: size, textColor: color)
        )
        onMarkdownChange?(markdown)
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

    private let fontSizes: [CGFloat] = [12, 14, 16, 18, 20, 24]

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            formatButton("B", help: "Bold") { formatting.toggleBold() }
            formatButton("I", help: "Italic") { formatting.toggleItalic() }
            formatButton("U", help: "Underline") { formatting.toggleUnderline() }
            formatButton("S", help: "Strikethrough") { formatting.toggleStrikethrough() }

            Divider().frame(height: 18)

            OWThemedDropdown(
                accessibilityLabel: "Font family",
                selection: fontFamilyBinding,
                options: [InlineMarkdown.FontFamily.serif, .sans],
                optionTitle: { $0 == .serif ? "Serif" : "Sans" },
                minWidth: 72,
                compact: true
            )

            OWThemedDropdown(
                accessibilityLabel: "Font size",
                selection: fontSizeBinding,
                options: fontSizes,
                optionTitle: { "\(Int($0))" },
                minWidth: 52,
                compact: true
            )

            Spacer(minLength: 0)
        }
        .font(OWTypography.captionEmphasis)
        .foregroundStyle(DesignTokens.Color.textSecondary)
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .padding(.vertical, DesignTokens.Spacing.spacing1)
        .background(
            DesignTokens.Color.surface.opacity(0.9),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: DesignTokens.Layout.borderWidth)
        }
        .opacity(formatting.focusedBlockID == nil ? 0.55 : 1)
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

    private func formatButton(_ title: String, help: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .frame(minWidth: 26, minHeight: 26)
                .background(
                    DesignTokens.Color.surfaceElevated.opacity(0.9),
                    in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                )
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .help(help)
        .disabled(formatting.focusedBlockID == nil)
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
