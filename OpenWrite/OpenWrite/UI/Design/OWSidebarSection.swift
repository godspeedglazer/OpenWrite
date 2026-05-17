import SwiftUI

// MARK: - Section header (custom disclosure, not List)

/// Collapsible sidebar section header — Anytype-style ▾ / ▸, not `DisclosureGroup` list chrome.
struct OWSidebarSectionHeader: View {
    let title: String
    @Binding var isExpanded: Bool

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Button {
            withAnimation(sectionAnimation) {
                isExpanded.toggle()
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.spacing1) {
                Text(isExpanded ? "▾" : "▸")
                    .font(OWTypography.caption.weight(.semibold))
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                    .frame(width: 20, alignment: .center)
                    .accessibilityHidden(true)

                Text(title.uppercased())
                    .font(OWTypography.railSectionLabel)
                    .tracking(OWTypography.railSectionTracking)
                    .foregroundStyle(DesignTokens.Color.textTertiary)

                Spacer(minLength: 0)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .padding(.horizontal, DesignTokens.Spacing.spacing2)
        .accessibilityAddTraits(.isHeader)
        .accessibilityLabel(title)
        .accessibilityValue(isExpanded ? "expanded" : "collapsed")
        .accessibilityHint("Double tap to \(isExpanded ? "collapse" : "expand") section")
    }

    private var sectionAnimation: Animation? {
        DesignTokens.Motion.animation(DesignTokens.Motion.animationStandard, reduceMotion: reduceMotion)
    }
}

// MARK: - Section container

/// Wraps rail section content with a collapsible header and optional sidebar card.
struct OWSidebarSection<Content: View>: View {
    let title: String
    @Binding var isExpanded: Bool
    var wrapsContentInCard: Bool = true
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
            OWSidebarSectionHeader(title: title, isExpanded: $isExpanded)

            if isExpanded {
                Group {
                    if wrapsContentInCard {
                        OWRoundedRect(style: .sidebarCard, padding: DesignTokens.Spacing.spacing1) {
                            content()
                        }
                    } else {
                        content()
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }
}

// MARK: - Object type row + filter submenu

/// Object-type nav row with expand chevron and filter hint submenu (clean-room Anytype tree row).
struct OWSidebarObjectTypeRow: View {
    let pageType: PageType
    let documentCount: Int
    let isFilterActive: Bool
    let onSelect: () -> Void

    @State private var isSubmenuExpanded = false
    @State private var isHovered = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 0) {
                Button {
                    withAnimation(rowAnimation) {
                        isSubmenuExpanded.toggle()
                    }
                } label: {
                    Text(isSubmenuExpanded ? "▾" : "▸")
                        .font(OWTypography.caption.weight(.semibold))
                        .foregroundStyle(DesignTokens.Color.textTertiary)
                        .frame(width: 24, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .help(isSubmenuExpanded ? "Hide filter hint" : "Show filter hint")

                Button(action: onSelect) {
                    HStack(spacing: DesignTokens.Spacing.spacing2) {
                        OWUnicodePageTypeIconWell(
                            pageType: pageType,
                            size: DesignTokens.Layout.objectIconWellSize
                        )

                        Text(pageType.displayName)
                            .font(OWTypography.sidebarItemEmphasis)
                            .foregroundStyle(DesignTokens.Color.textPrimary)
                            .lineLimit(1)

                        Spacer(minLength: 0)

                        if isFilterActive {
                            Text("On")
                                .font(OWTypography.captionEmphasis)
                                .foregroundStyle(DesignTokens.Color.accent)
                        } else if documentCount > 0 {
                            Text("\(documentCount)")
                                .font(OWTypography.caption)
                                .foregroundStyle(DesignTokens.Color.textTertiary)
                        }
                    }
                    .padding(.trailing, DesignTokens.Spacing.spacing2)
                    .padding(.vertical, 1)
                    .frame(minHeight: 28)
                    .background {
                        if isFilterActive || isHovered {
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                                .fill(rowBackgroundColor)
                                .padding(1)
                        }
                    }
                    .overlay {
                        if isFilterActive {
                            RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                                .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: DesignTokens.Layout.borderWidth)
                                .padding(1)
                        }
                    }
                }
                .buttonStyle(.plain)
                .onHover { isHovered = $0 }
            }

            if isSubmenuExpanded {
                Text(filterHint)
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 24 + DesignTokens.Spacing.spacing2)
                    .padding(.trailing, DesignTokens.Spacing.spacing2)
                    .padding(.bottom, DesignTokens.Spacing.spacing1)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .animation(rowAnimation, value: isSubmenuExpanded)
        .animation(rowAnimation, value: isFilterActive)
        .onChange(of: isFilterActive) { _, active in
            if active {
                isSubmenuExpanded = true
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityAddTraits(isFilterActive ? .isSelected : [])
    }

    private var filterHint: String {
        let name = pageType.displayName.lowercased()
        if isFilterActive {
            return "Vault list shows only \(name) pages. Tap the row again to clear the filter."
        }
        if documentCount == 0 {
            return "Filter vault to \(name). No pages yet — create one from Vault when filtered."
        }
        return "Filter vault to \(name) (\(documentCount) page\(documentCount == 1 ? "" : "s"))."
    }

    private var rowBackgroundColor: Color {
        if isFilterActive {
            return DesignTokens.Color.selectionPill
        }
        return DesignTokens.Color.textPrimary.opacity(DesignTokens.Opacity.overlayLight)
    }

    private var rowAnimation: Animation? {
        DesignTokens.Motion.animation(DesignTokens.Motion.animationFast, reduceMotion: reduceMotion)
    }

    private var accessibilityLabel: String {
        var parts = [pageType.displayName]
        if isFilterActive {
            parts.append("filter active")
        }
        parts.append("\(documentCount) pages")
        if isSubmenuExpanded {
            parts.append(filterHint)
        }
        return parts.joined(separator: ", ")
    }
}
