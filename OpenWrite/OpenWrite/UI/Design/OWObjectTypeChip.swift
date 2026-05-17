import SwiftUI

// MARK: - OWObjectTypeChip

/// Object-type pill — see docs/design/OWComponents.md.
struct OWObjectTypeChip: View {
    let pageType: PageType
    var showsIcon: Bool = true

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.spacing1) {
            if showsIcon {
                OWUnicodeIconView(pageType: pageType, size: 12, color: DesignTokens.ObjectType.accent(for: pageType))
            }
            Text(pageType.displayName)
                .font(DesignTokens.Typography.captionEmphasis)
        }
        .foregroundStyle(DesignTokens.ObjectType.accent(for: pageType))
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .frame(minHeight: DesignTokens.Layout.objectTypeChipHeight)
        .background(
            DesignTokens.ObjectType.chipBackground(for: pageType),
            in: Capsule(style: .continuous)
        )
        .accessibilityLabel("\(pageType.displayName) type")
    }
}
