import SwiftUI

// MARK: - OWPreviewBlockRow

/// Filled block-style preview row for rendered note content (Anytype-inspired density, clean-room).
struct OWPreviewBlockRow: View {
    let block: NoteBlock
    var text: Binding<String>? = nil

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
            case .wikilink:
                linkRow
            case .property:
                propertyRow
            case .paragraph:
                paragraphRow
            }
        }
    }

    private var headingRow: some View {
        inlineText(font: headingFont, foreground: DesignTokens.Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignTokens.Spacing.spacing1)
    }

    private var paragraphRow: some View {
        inlineText(font: DesignTokens.Typography.body, foreground: DesignTokens.Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.spacing3)
            .background(blockFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var bulletRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
            Text("•")
                .font(DesignTokens.Typography.bodyEmphasis)
                .foregroundStyle(DesignTokens.Color.textSecondary)
            inlineText(font: DesignTokens.Typography.body, foreground: DesignTokens.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.spacing3)
        .background(blockFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var calloutRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
            OWIconView(icon: calloutIcon, size: 16, color: calloutAccent)
                .padding(.top, 2)
            inlineText(font: DesignTokens.Typography.body, foreground: DesignTokens.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.spacing3)
        .background(calloutFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                .strokeBorder(calloutAccent.opacity(0.22), lineWidth: 1)
        }
    }

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
        Group {
            if isEditing, let text {
                TextField("Code", text: text, axis: .vertical)
                    .textFieldStyle(.plain)
                    .font(DesignTokens.Typography.code)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
            } else {
                Text(block.text)
                    .font(DesignTokens.Typography.code)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(DesignTokens.Spacing.spacing3)
        .background(DesignTokens.Color.codeBackground, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var linkRow: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            OWIconView(icon: .link, size: 14, color: DesignTokens.Color.wikilink)
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
    private func inlineText(font: Font, foreground: Color) -> some View {
        if let text {
            TextField("", text: text, axis: .vertical)
                .textFieldStyle(.plain)
                .font(font)
                .foregroundStyle(foreground)
                .lineLimit(1...8)
        } else {
            Text(block.text)
                .font(font)
                .foregroundStyle(foreground)
        }
    }

    private var blockFill: Color {
        DesignTokens.Color.surfaceElevated.opacity(0.92)
    }

    private var calloutVariant: String {
        block.attributes["callout"] ?? "note"
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
}
