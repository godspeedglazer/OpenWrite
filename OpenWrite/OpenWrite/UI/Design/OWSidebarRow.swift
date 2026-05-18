import SwiftUI

// MARK: - OWSidebarRow

/// Custom sidebar list row — individual OW Rect pill per row (Anytype-style).
struct OWSidebarRow: View {
    let title: String
    var subtitle: String?
    var pageType: PageType?
    var customIcon: OWIcon?
    var pageIconCharacter: String?
    var iconTint: Color?
    var showsGraphGlyph: Bool = false
    let isSelected: Bool
    let action: () -> Void

    @Environment(\.openWritePalette) private var palette
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var rowIcon: OWIcon {
        if showsGraphGlyph { return .graph }
        if let customIcon { return customIcon }
        if let pageType { return pageType.owIcon }
        return .note
    }

    var body: some View {
        Button(action: action) {
            HStack(spacing: DesignTokens.Spacing.spacing2) {
                if let pageIconCharacter, !pageIconCharacter.isEmpty, !showsGraphGlyph {
                    OWUnicodePageTypeIconWell(
                        character: pageIconCharacter,
                        pageType: pageTypeForWell,
                        size: DesignTokens.Layout.objectIconWellSize
                    )
                } else if let iconTint {
                    OWUnicodeIconView(icon: rowIcon, size: 18, color: iconTint)
                        .frame(width: 28, height: 28)
                        .background(iconTint.opacity(0.14), in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous))
                } else {
                    OWUnicodePageTypeIconWell(
                        icon: rowIcon,
                        pageType: pageTypeForWell,
                        size: DesignTokens.Layout.objectIconWellSize
                    )
                }

                VStack(alignment: .leading, spacing: subtitle == nil ? 0 : DesignTokens.Spacing.sidebarRowSubtitleSpacing) {
                    Text(title)
                        .font(OWTypography.sidebarItemEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .lineLimit(1)

                    if let subtitle {
                        Text(subtitle)
                            .font(OWTypography.caption)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                            .lineLimit(2)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.trailing, DesignTokens.Spacing.spacing1)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.vertical, DesignTokens.Spacing.spacing1)
            .frame(
                minHeight: subtitle == nil
                    ? DesignTokens.Layout.sidebarRowMinHeight
                    : DesignTokens.Layout.sidebarRowTallMinHeight,
                alignment: .center
            )
            .background(rowBackground, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous))
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                        .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: DesignTokens.Layout.borderWidth)
                }
            }
            .contentShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous))
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .onHover { isHovered = $0 }
        .animation(selectionAnimation, value: isSelected)
        .animation(selectionAnimation, value: isHovered)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var pageTypeForWell: PageType? {
        showsGraphGlyph ? nil : pageType
    }

    private var rowBackground: Color {
        if isSelected {
            return palette.selectionPill
        }
        if isHovered {
            return palette.textPrimary.opacity(DesignTokens.Opacity.overlayLight)
        }
        return palette.surface.opacity(0.62)
    }

    private var selectionAnimation: Animation? {
        DesignTokens.Motion.animation(DesignTokens.Motion.animationFast, reduceMotion: reduceMotion)
    }

    private var accessibilityLabel: String {
        var parts = [title]
        if let subtitle {
            parts.append(subtitle)
        }
        if isSelected {
            parts.append("selected")
        }
        return parts.joined(separator: ", ")
    }
}
