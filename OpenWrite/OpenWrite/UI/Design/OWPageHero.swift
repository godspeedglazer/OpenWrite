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
    /// Smaller type and icon when the host column is narrow (graph empty states).
    var narrow: Bool = false

    var body: some View {
        VStack(spacing: verticalSpacing) {
            if style == .emptyState {
                OWUnicodeIconView(icon: icon, size: narrow ? 32 : 40, color: heroIconColor)
            }

            if style == .documentHeader, let pageType {
                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    OWObjectTypeChip(pageType: pageType)
                    Spacer()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Text(title)
                .font(narrow ? OWTypography.heading2 : OWTypography.documentTitle)
                .lineSpacing(narrow ? OWTypography.heading2LineSpacing : OWTypography.documentTitleLineSpacing)
                .foregroundStyle(DesignTokens.Color.textPrimary)
                .multilineTextAlignment(style == .emptyState ? .center : .leading)
                .frame(maxWidth: .infinity, alignment: alignment)

            if let subtitle {
                Text(subtitle)
                    .font(narrow ? OWTypography.caption : OWTypography.callout)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .multilineTextAlignment(style == .emptyState ? .center : .leading)
                    .frame(maxWidth: .infinity, alignment: alignment)
                    .fixedSize(horizontal: false, vertical: true)
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
