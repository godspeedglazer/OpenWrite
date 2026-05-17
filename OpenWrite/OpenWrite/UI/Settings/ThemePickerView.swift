import SwiftUI

/// Compact cycle control for the sidebar gear sheet and Settings header.
struct ThemeQuickToggle: View {
    @Environment(ThemeManager.self) private var themeManager

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.spacing3) {
            Button {
                themeManager.selectNext()
            } label: {
                HStack(spacing: DesignTokens.Spacing.spacing2) {
                    themeMiniSwatch(themeManager.palette)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(themeManager.selectedTheme.displayName)
                            .font(DesignTokens.Typography.captionEmphasis)
                            .foregroundStyle(DesignTokens.Color.textPrimary)
                        Text("Tap to cycle themes")
                            .font(DesignTokens.Typography.caption)
                            .foregroundStyle(DesignTokens.Color.textTertiary)
                    }
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Cycle theme, currently \(themeManager.selectedTheme.displayName)")

            Spacer()

            Menu {
                ForEach(ThemeID.allCases) { theme in
                    Button {
                        themeManager.select(theme)
                    } label: {
                        HStack {
                            Text(theme.displayName)
                            if themeManager.selectedTheme == theme {
                                Spacer(minLength: 8)
                                OWIconView(icon: .checkmark, size: 12, color: DesignTokens.Color.accent)
                            }
                        }
                    }
                }
            } label: {
                OWIconView(icon: .sliders, size: 16, color: DesignTokens.Color.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(DesignTokens.Color.selectionPill.opacity(0.9), in: Circle())
            }
            .menuStyle(.borderlessButton)
            .help("Choose theme")
        }
        .padding(DesignTokens.Spacing.spacing3)
        .background(DesignTokens.Color.surface, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
    }

    private func themeMiniSwatch(_ palette: ThemePalette) -> some View {
        HStack(spacing: 0) {
            palette.sidebarBackground.frame(width: 10)
            VStack(spacing: 0) {
                palette.workbenchChrome.frame(height: 6)
                palette.editorCanvas
                palette.accent.frame(height: 4)
            }
        }
        .frame(width: 36, height: 28)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 0.5)
        }
    }
}

/// Grid of theme previews for Settings and the sidebar gear sheet.
struct ThemePickerView: View {
    @Environment(ThemeManager.self) private var themeManager

  private let columns = [
        GridItem(.adaptive(minimum: 148, maximum: 200), spacing: DesignTokens.Spacing.spacing3)
    ]

    var body: some View {
        LazyVGrid(columns: columns, spacing: DesignTokens.Spacing.spacing3) {
            ForEach(ThemeID.allCases) { theme in
                ThemePreviewCard(
                    theme: theme,
                    palette: ThemePalette.palette(for: theme),
                    isSelected: themeManager.selectedTheme == theme
                ) {
                    themeManager.select(theme)
                }
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Appearance themes")
    }
}

// MARK: - Preview card

private struct ThemePreviewCard: View {
    let theme: ThemeID
    let palette: ThemePalette
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing2) {
                themeSwatch
                Text(theme.displayName)
                    .font(DesignTokens.Typography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .lineLimit(1)
                Text(theme.shortDescription)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(DesignTokens.Spacing.spacing3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(DesignTokens.Color.surfaceElevated, in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .strokeBorder(
                        isSelected ? DesignTokens.Color.accent : DesignTokens.Color.borderSubtle,
                        lineWidth: isSelected ? 2 : 1
                    )
            }
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? [.isSelected, .isButton] : .isButton)
        .accessibilityLabel("\(theme.displayName) theme")
    }

    private var themeSwatch: some View {
        HStack(spacing: 0) {
            palette.sidebarBackground
                .frame(width: 28)
            VStack(spacing: 0) {
                palette.workbenchChrome
                    .frame(height: 10)
                palette.editorCanvas
                palette.accent
                    .frame(height: 6)
            }
        }
        .frame(height: 52)
        .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous))
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                .strokeBorder(palette.borderSubtle, lineWidth: 0.5)
        }
    }
}

#Preview {
    ThemePickerView()
        .environment(ThemeManager.shared)
        .padding()
}
