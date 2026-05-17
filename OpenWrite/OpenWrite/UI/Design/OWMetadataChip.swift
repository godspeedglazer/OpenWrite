import SwiftUI

// MARK: - OWMetadataChip

/// Single inline metadata pill under the page hero — clean-room Anytype featured-row pattern.
struct OWMetadataChip: View {
    let label: String
    var icon: OWIcon?
    var value: String?

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.spacing1) {
            if let icon {
                OWIconView(icon: icon, size: 12, color: DesignTokens.Color.textTertiary)
            }
            if value != nil {
                Text(label)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                Text(value ?? "")
                    .font(DesignTokens.Typography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .lineLimit(1)
            } else {
                Text(label)
                    .font(DesignTokens.Typography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, DesignTokens.Spacing.spacing3)
        .padding(.vertical, DesignTokens.Spacing.spacing2)
        .background(chipBackground, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.metadataChip, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.metadataChip, style: .continuous)
                .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: 0.5)
        }
        .onHover { isHovered = $0 }
    }

    private var chipBackground: Color {
        isHovered
            ? DesignTokens.Color.selectionPill
            : DesignTokens.Color.surface.opacity(0.85)
    }
}
