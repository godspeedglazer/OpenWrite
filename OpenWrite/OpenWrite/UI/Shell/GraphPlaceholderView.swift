// Graph shell placeholder — layout inspired by Anytype graph mode (clean-room).
// See docs/design/AnytypeUIInspiration.md and docs/features/GraphView.md.

import SwiftUI

struct GraphPlaceholderView: View {
    var body: some View {
        VStack(spacing: DesignTokens.Spacing.spacing6) {
            OWIconView(icon: .graph, size: 56, color: DesignTokens.Color.accent.opacity(0.35))

            Text("Vault graph")
                .font(OWTypography.heading2)
                .foregroundStyle(DesignTokens.Color.textPrimary)

            Text("Link notes with [[wikilinks]] to see your local topology here. Open Graph in the center tab to explore connections.")
                .font(OWTypography.callout)
                .foregroundStyle(DesignTokens.Color.textSecondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)

            OWRoundedRect(style: .elevated, padding: DesignTokens.Spacing.spacing4) {
                VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                    OWLabel(title: "Try linking", icon: .link)
                        .font(OWTypography.bodyEmphasis)
                    Text("[[Welcome to OpenWrite]] connects pages in your encrypted vault.")
                        .font(OWTypography.caption)
                        .foregroundStyle(DesignTokens.Color.textSecondary)
                }
            }
            .frame(maxWidth: 480)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(DesignTokens.Spacing.spacing8)
    }
}
