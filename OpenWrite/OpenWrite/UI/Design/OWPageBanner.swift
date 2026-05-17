import SwiftUI

// MARK: - OWPageBanner

/// Playground-style page header: optional cover gradient with emoji icon anchored on the strip.
struct OWPageBanner<Metadata: View>: View {
    @Environment(\.openWritePalette) private var palette

    let title: String
    let icon: OWIcon
    var pageType: PageType?
    var pageIconCharacter: String?
    var coverStyle: CoverStyle?
    var showsGradient: Bool = true
    @ViewBuilder var metadata: () -> Metadata

    private var stripHeight: CGFloat { OWPageBannerMetrics.stripHeight }
    private var iconSize: CGFloat { OWPageBannerMetrics.iconSize }
    private var iconOverlap: CGFloat { OWPageBannerMetrics.iconOverlap }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if showsGradient {
                    OWPageBannerGradient(
                        coverStyle: coverStyle,
                        pageType: pageType,
                        stripHeight: stripHeight
                    )
                    .frame(maxWidth: .infinity)
                }

                pageIconWell
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                            .strokeBorder(palette.editorCanvas, lineWidth: 2)
                    }
                    .shadow(color: .black.opacity(0.08), radius: 6, y: 2)
                    .padding(.leading, DesignTokens.Spacing.spacing3)
                    .offset(y: showsGradient ? iconOverlap : 0)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                OWPageTitleBand(title: title)

                metadata()
            }
            .openWriteEditorContentWidth()
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.top, showsGradient ? iconOverlap + DesignTokens.Spacing.spacing2 : DesignTokens.Spacing.spacing2)
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.bottom, DesignTokens.Spacing.spacing2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private var pageIconWell: some View {
        if let pageIconCharacter, !pageIconCharacter.isEmpty {
            OWUnicodePageTypeIconWell(character: pageIconCharacter, pageType: pageType, size: iconSize)
        } else {
            OWUnicodePageTypeIconWell(icon: icon, pageType: pageType, size: iconSize)
        }
    }

}

// MARK: - Static title band (non-editor surfaces)

/// Read-only document title typography for banners and secondary views.
struct OWPageTitleBand: View {
    let title: String
    var showsFontWarning: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            if showsFontWarning, OWTypography.showsBundledSerifWarningInUI {
                OWTypographyFontWarningBanner()
            }

            Text(title)
                .font(OWTypography.documentTitle)
                .lineSpacing(OWTypography.documentTitleLineSpacing)
                .foregroundStyle(DesignTokens.Color.textPrimary)
                .lineLimit(4)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
