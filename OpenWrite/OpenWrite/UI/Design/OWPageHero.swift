import SwiftUI

// MARK: - OWPageHero

/// Editor-column hero for titles and empty states — see docs/design/OWComponents.md.
struct OWPageHero: View {
    enum Style {
        case emptyState
        case documentHeader
    }

    let title: String
    var subtitle: String?
    let icon: OWIcon
    var pageType: PageType?
    var style: Style = .emptyState
    /// Tighter insets for graph / secondary empty states.
    var compact: Bool = false

    var body: some View {
        VStack(spacing: verticalSpacing) {
            if style == .emptyState {
                OWIconView(icon: icon, size: 40, color: heroIconColor)
            }

            if style == .documentHeader, let pageType {
                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    OWObjectTypeChip(pageType: pageType)
                    Spacer()
                }
                .frame(maxWidth: DesignTokens.Layout.editorMaxContentWidth)
            }

            Text(title)
                .font(OWTypography.documentTitle)
                .foregroundStyle(DesignTokens.Color.textPrimary)
                .multilineTextAlignment(style == .emptyState ? .center : .leading)
                .frame(maxWidth: DesignTokens.Layout.editorMaxContentWidth, alignment: alignment)

            if let subtitle {
                Text(subtitle)
                    .font(OWTypography.callout)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .multilineTextAlignment(style == .emptyState ? .center : .leading)
                    .frame(maxWidth: DesignTokens.Layout.editorMaxContentWidth, alignment: alignment)
            }
        }
        .padding(compact ? DesignTokens.Spacing.editorHeroPadding : DesignTokens.Spacing.editorPadding)
        .frame(maxWidth: .infinity, alignment: style == .emptyState ? .center : .leading)
    }

    private var verticalSpacing: CGFloat {
        switch style {
        case .emptyState:
            return DesignTokens.Spacing.spacing4
        case .documentHeader:
            return DesignTokens.Spacing.spacing2
        }
    }

    private var alignment: Alignment {
        style == .emptyState ? .center : .leading
    }

    private var heroIconColor: Color {
        if let pageType {
            return DesignTokens.ObjectType.accent(for: pageType)
        }
        return DesignTokens.Color.accent
    }
}
