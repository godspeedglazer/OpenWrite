import SwiftUI

// MARK: - OWPreviewBlockRow

/// Filled block-style preview row for rendered note content (Anytype-inspired density, clean-room).
struct OWPreviewBlockRow: View {
    let block: NoteBlock

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
        Text(block.text)
            .font(headingFont)
            .foregroundStyle(DesignTokens.Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, DesignTokens.Spacing.spacing1)
    }

    private var paragraphRow: some View {
        Text(block.text)
            .font(DesignTokens.Typography.body)
            .foregroundStyle(DesignTokens.Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.spacing3)
            .background(blockFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var bulletRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
            Text("•")
                .font(DesignTokens.Typography.bodyEmphasis)
                .foregroundStyle(DesignTokens.Color.textSecondary)
            Text(block.text)
                .font(DesignTokens.Typography.body)
                .foregroundStyle(DesignTokens.Color.textPrimary)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.spacing3)
        .background(blockFill, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var quoteRow: some View {
        HStack(alignment: .top, spacing: DesignTokens.Spacing.spacing2) {
            RoundedRectangle(cornerRadius: 2, style: .continuous)
                .fill(DesignTokens.Color.accent.opacity(0.55))
                .frame(width: DesignTokens.Layout.quoteBarWidth)
            Text(block.text)
                .font(DesignTokens.Typography.callout)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .italic()
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(DesignTokens.Spacing.spacing3)
        .background(blockFill.opacity(0.85), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var codeRow: some View {
        Text(block.text)
            .font(DesignTokens.Typography.code)
            .foregroundStyle(DesignTokens.Color.textPrimary)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(DesignTokens.Spacing.spacing3)
            .background(DesignTokens.Color.codeBackground, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private var linkRow: some View {
        HStack(spacing: DesignTokens.Spacing.spacing2) {
            OWIconView(icon: .link, size: 14, color: DesignTokens.Color.wikilink)
            Text(block.text)
                .font(DesignTokens.Typography.bodyEmphasis)
                .foregroundStyle(DesignTokens.Color.wikilink)
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

    private var blockFill: Color {
        DesignTokens.Color.surfaceElevated.opacity(0.92)
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
