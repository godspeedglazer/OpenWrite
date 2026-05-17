import AppKit
import SwiftUI

// MARK: - OWPreviewBlockRow

/// Filled block-style preview row for rendered note content (Anytype-inspired density, clean-room).
struct OWPreviewBlockRow: View {
    let block: NoteBlock
    var text: Binding<String>? = nil
    var checked: Binding<Bool>? = nil
    var language: Binding<String>? = nil
    var calloutType: Binding<String>? = nil

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
    }

    private var headingRow: some View {
        inlineText(
            font: headingFont,
            lineSpacing: headingLineSpacing,
            foreground: DesignTokens.Color.textPrimary
        )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.spacing3)
            .background(blockFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var paragraphRow: some View {
        inlineText(
            font: DesignTokens.Typography.body,
            lineSpacing: DesignTokens.Typography.bodyLineSpacing,
            foreground: DesignTokens.Color.textPrimary
        )
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.spacing3)
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
        .padding(DesignTokens.Spacing.spacing3)
        .background(blockFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var todoRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
            todoCheckbox
            inlineText(
                font: DesignTokens.Typography.body,
                lineSpacing: DesignTokens.Typography.bodyLineSpacing,
                foreground: isTodoChecked ? DesignTokens.Color.textSecondary : DesignTokens.Color.textPrimary
            )
            .strikethrough(isTodoChecked && !isEditing)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.spacing3)
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
            }
            .buttonStyle(.plain)
            .padding(.top, 2)
        } else {
            todoCheckboxGlyph(filled: filled)
                .padding(.top, 2)
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
        HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
            calloutLeading
            inlineText(
                font: DesignTokens.Typography.body,
                lineSpacing: DesignTokens.Typography.bodyLineSpacing,
                foreground: DesignTokens.Color.textPrimary
            )
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.spacing3)
        .background(calloutFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .strokeBorder(calloutAccent.opacity(0.22), lineWidth: 1)
        }
    }

    @ViewBuilder
    private var calloutLeading: some View {
        if let calloutType, isEditing {
            Menu {
                ForEach(Self.calloutVariants, id: \.self) { variant in
                    Button(variant.capitalized) {
                        calloutType.wrappedValue = variant
                    }
                }
            } label: {
                OWUnicodeIconView(icon: calloutIcon, size: 16, color: calloutAccent)
            }
            .menuStyle(.borderlessButton)
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
        .padding(DesignTokens.Spacing.spacing3)
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
        .padding(DesignTokens.Spacing.spacing3)
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
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            OWUnicodeIconView(icon: .link, size: 14, color: DesignTokens.Color.wikilink)
            if isEditing, let text {
                TextField("Link title", text: text)
                    .textFieldStyle(.plain)
                    .font(DesignTokens.Typography.bodyEmphasis)
                    .foregroundStyle(DesignTokens.Color.wikilink)
            } else {
                Text(block.text)
                    .font(DesignTokens.Typography.bodyEmphasis)
                    .foregroundStyle(DesignTokens.Color.wikilink)
            }
        }
        .padding(DesignTokens.Spacing.spacing3)
        .background(DesignTokens.Color.wikilink.opacity(0.08), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var imageRow: some View {
        Group {
            if let url = VaultAttachmentStore.resolveFileURL(for: block),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity, maxHeight: 360, alignment: .leading)
                    .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
            } else {
                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    OWUnicodeIconView(icon: .missingNote, size: 16, color: DesignTokens.Color.textTertiary)
                    Text(block.text.isEmpty ? "Missing image" : block.text)
                        .font(DesignTokens.Typography.caption)
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(DesignTokens.Spacing.spacing3)
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
        .padding(.horizontal, DesignTokens.Spacing.spacing3)
        .padding(.vertical, DesignTokens.Spacing.spacing2)
        .background(DesignTokens.Color.surfaceElevated, in: Capsule())
    }

    @ViewBuilder
    private func inlineText(font: Font, lineSpacing: CGFloat = 0, foreground: Color) -> some View {
        if let text {
            TextField("", text: text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(font)
                .lineSpacing(lineSpacing)
                .foregroundStyle(foreground)
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(block.text)
                .font(font)
                .lineSpacing(lineSpacing)
                .foregroundStyle(foreground)
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private var blockFill: Color {
        DesignTokens.Color.surfaceElevated.opacity(0.92)
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
}
