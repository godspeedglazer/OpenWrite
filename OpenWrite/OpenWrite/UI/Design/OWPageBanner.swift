import SwiftUI

// MARK: - OWPageBanner

/// Playground-style page header: optional type-tinted gradient band with icon anchored on the strip.
struct OWPageBanner<Metadata: View>: View {
    @Environment(\.openWritePalette) private var palette

    let title: String
    let icon: OWIcon
    var pageType: PageType?
    var showsGradient: Bool = true
    @ViewBuilder var metadata: () -> Metadata

    private let stripHeight: CGFloat = 88
    private let iconSize: CGFloat = 44
    private let iconOverlap: CGFloat = 22

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ZStack(alignment: .bottomLeading) {
                if showsGradient {
                    gradientStrip
                        .frame(height: stripHeight)
                        .frame(maxWidth: .infinity)
                }

                OWPageTypeIconWell(icon: icon, pageType: pageType, size: iconSize)
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
                Text(title)
                    .font(OWTypography.documentTitle)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .lineLimit(4)
                    .fixedSize(horizontal: false, vertical: true)

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

    private var gradientStrip: some View {
        LinearGradient(
            colors: gradientColors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(alignment: .bottom) {
            LinearGradient(
                colors: [
                    palette.editorCanvas.opacity(0),
                    palette.editorCanvas
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 28)
        }
    }

    private var gradientColors: [Color] {
        let accent = pageType.map { DesignTokens.ObjectType.accent(for: $0) } ?? DesignTokens.Color.accent
        return [
            accent.opacity(0.42),
            accent.opacity(0.18),
            palette.editorCanvas.opacity(0.05)
        ]
    }
}
