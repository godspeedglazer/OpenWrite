import SwiftUI

// MARK: - OWSidebarRow

/// Custom sidebar list row with pill selection — see docs/design/OWComponents.md.
struct OWSidebarRow: View {
    let title: String
    var subtitle: String?
    var pageType: PageType?
    var customIcon: OWIcon?
    var pageIconCharacter: String?
    var iconTint: Color?
    var showsGraphGlyph: Bool = false
    /// Tighter vault/object list density.
    var dense: Bool = false
    let isSelected: Bool
    let action: () -> Void

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

                VStack(alignment: .leading, spacing: dense ? 0 : 2) {
                    Text(title)
                        .font(OWTypography.sidebarItemEmphasis)
                        .foregroundStyle(DesignTokens.Color.textPrimary)
                        .lineLimit(1)

                    if let subtitle, !dense {
                        Text(subtitle)
                            .font(OWTypography.caption)
                            .foregroundStyle(DesignTokens.Color.textSecondary)
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing2)
            .padding(.vertical, dense ? 1 : (subtitle == nil ? 2 : DesignTokens.Spacing.spacing1))
            .frame(minHeight: dense ? 28 : DesignTokens.Layout.sidebarRowHeight)
            .background {
                if isSelected || isHovered {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                        .fill(rowBackgroundColor)
                        .padding(1)
                }
            }
            .overlay {
                if isSelected {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                        .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: DesignTokens.Layout.borderWidth)
                        .padding(1)
                }
            }
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .animation(selectionAnimation, value: isSelected)
        .animation(selectionAnimation, value: isHovered)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }

    private var pageTypeForWell: PageType? {
        showsGraphGlyph ? nil : pageType
    }

    private var rowBackgroundColor: Color {
        if isSelected {
            return DesignTokens.Color.selectionPill
        }
        return DesignTokens.Color.textPrimary.opacity(DesignTokens.Opacity.overlayLight)
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
