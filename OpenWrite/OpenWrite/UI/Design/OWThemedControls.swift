import SwiftUI

// MARK: - Settings sheet chrome

/// Themed settings / modal shell — `shellChrome` header, `background` body, accent Done.
struct OWSettingsSheet<Content: View>: View {
    let title: String
    let onDone: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.spacing3) {
                Text(title)
                    .font(DesignTokens.Typography.heading3)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                Spacer(minLength: 0)
                Button("Done", action: onDone)
                    .buttonStyle(OWAccentCapsuleButtonStyle())
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing4)
            .padding(.vertical, DesignTokens.Spacing.spacing3)
            .background(DesignTokens.Color.shellChrome)

            Rectangle()
                .fill(DesignTokens.Color.separator)
                .frame(height: DesignTokens.Layout.borderWidth)

            content()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .background(DesignTokens.Color.background)
    }
}

// MARK: - Buttons

struct OWAccentCapsuleButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.captionEmphasis)
            .foregroundStyle(DesignTokens.Color.selectionPill)
            .padding(.horizontal, DesignTokens.Spacing.spacing4)
            .padding(.vertical, DesignTokens.Spacing.spacing2)
            .background(
                DesignTokens.Color.accent.opacity(configuration.isPressed ? 0.82 : 1),
                in: Capsule()
            )
    }
}

struct OWSecondaryRectButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(DesignTokens.Typography.captionEmphasis)
            .foregroundStyle(DesignTokens.Color.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.vertical, DesignTokens.Spacing.spacing2)
            .background(
                DesignTokens.Color.surfaceElevated.opacity(configuration.isPressed ? 0.75 : 0.95),
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
            }
    }
}

// MARK: - Text field

struct OWThemedTextField: View {
    let placeholder: String
    @Binding var text: String
    var onSubmit: (() -> Void)?

    var body: some View {
        TextField(placeholder, text: $text)
            .textFieldStyle(.plain)
            .font(DesignTokens.Typography.body)
            .foregroundStyle(DesignTokens.Color.textPrimary)
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.vertical, DesignTokens.Spacing.spacing2)
            .background(
                DesignTokens.Color.surfaceElevated,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
            }
            .onSubmit { onSubmit?() }
    }
}

// MARK: - Dropdown (popover menu)

struct OWThemedDropdown<Option: Hashable>: View {
    let accessibilityLabel: String
    @Binding var selection: Option
    let options: [Option]
    let optionTitle: (Option) -> String
    var minWidth: CGFloat = 120
    var compact: Bool = false
    var leadingIcon: OWIcon?

    @State private var isOpen = false

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            HStack(spacing: DesignTokens.Spacing.spacing1) {
                if let leadingIcon {
                    OWUnicodeIconView(
                        icon: leadingIcon,
                        size: compact ? 12 : 14,
                        color: DesignTokens.Color.accent
                    )
                }
                Text(optionTitle(selection))
                    .font(compact ? OWTypography.captionEmphasis : DesignTokens.Typography.captionEmphasis)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .lineLimit(1)
                OWUnicodeIconView(icon: .chevronDown, size: compact ? 8 : 10, color: DesignTokens.Color.textTertiary)
            }
            .padding(.horizontal, compact ? DesignTokens.Spacing.spacing2 : DesignTokens.Spacing.spacing3)
            .padding(.vertical, compact ? 4 : DesignTokens.Spacing.spacing2)
            .frame(minWidth: minWidth, alignment: .leading)
            .background(
                DesignTokens.Color.surfaceElevated.opacity(0.95),
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .popover(isPresented: $isOpen, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            dropdownList
                .padding(DesignTokens.Spacing.spacing2)
        }
    }

    private var dropdownList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
                ForEach(options, id: \.self) { option in
                    dropdownRow(option)
                }
            }
        }
        .frame(minWidth: max(minWidth, 160), maxHeight: 280)
        .background(DesignTokens.Color.surfaceElevated)
    }

    private func dropdownRow(_ option: Option) -> some View {
        let isSelected = option == selection
        return Button {
            selection = option
            isOpen = false
        } label: {
            HStack(spacing: DesignTokens.Spacing.spacing2) {
                Text(optionTitle(option))
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                    .lineLimit(2)
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
                if isSelected {
                    OWUnicodeIconView(icon: .checkmark, size: 12, color: DesignTokens.Color.accent)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.vertical, DesignTokens.Spacing.spacing2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                isSelected ? DesignTokens.Color.accentMuted : DesignTokens.Color.surface,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Segmented control

struct OWThemedSegmentedControl<Option: Hashable>: View {
    @Binding var selection: Option
    let options: [Option]
    let title: (Option) -> String
    var icon: ((Option) -> OWIcon)?
    /// Icon-only segments for narrow assist strip widths.
    var iconsOnly: Bool = false

    var body: some View {
        HStack(spacing: DesignTokens.Spacing.spacing1) {
            ForEach(options, id: \.self) { option in
                segmentButton(option)
            }
        }
        .padding(3)
        .background(
            DesignTokens.Color.surface.opacity(0.9),
            in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
        )
        .overlay {
            RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                .strokeBorder(DesignTokens.Color.borderHairline, lineWidth: DesignTokens.Layout.borderWidth)
        }
    }

    private func segmentButton(_ option: Option) -> some View {
        let isSelected = option == selection
        return Button {
            withAnimation(DesignTokens.Motion.animationFast) {
                selection = option
            }
        } label: {
            HStack(spacing: 4) {
                if let icon {
                    OWUnicodeIconView(
                        icon: icon(option),
                        size: 12,
                        color: isSelected ? DesignTokens.Color.accent : DesignTokens.Color.textTertiary
                    )
                }
                if !iconsOnly {
                    Text(title(option))
                        .font(OWTypography.caption2)
                        .foregroundStyle(isSelected ? DesignTokens.Color.textPrimary : DesignTokens.Color.textTertiary)
                        .lineLimit(1)
                }
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing2)
            .padding(.vertical, 4)
            .frame(maxWidth: .infinity)
            .background(
                isSelected ? DesignTokens.Color.selectionPill : Color.clear,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .accessibilityLabel(title(option))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Toggle

struct OWThemedToggle: View {
    let label: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            withAnimation(DesignTokens.Motion.animationFast) {
                isOn.toggle()
            }
        } label: {
            HStack(spacing: DesignTokens.Spacing.spacing2) {
                Text(label)
                    .font(OWTypography.caption)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                Spacer(minLength: 0)
                ZStack(alignment: isOn ? .trailing : .leading) {
                    Capsule()
                        .fill(isOn ? DesignTokens.Color.accent : DesignTokens.Color.borderSubtle)
                        .frame(width: 36, height: 20)
                    Circle()
                        .fill(DesignTokens.Color.selectionPill)
                        .frame(width: 16, height: 16)
                        .padding(2)
                }
                .animation(DesignTokens.Motion.animationFast, value: isOn)
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
    }
}

// MARK: - Settings section card

struct OWSettingsSection<Content: View>: View {
    let title: String
    var footer: String?
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
            Text(title)
                .font(DesignTokens.Typography.captionEmphasis)
                .foregroundStyle(DesignTokens.Color.textSecondary)

            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing3) {
                content()
            }
            .padding(DesignTokens.Spacing.spacing3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                DesignTokens.Color.surface,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderSubtle.opacity(0.65), lineWidth: DesignTokens.Layout.borderWidth)
            }

            if let footer {
                Text(footer)
                    .font(DesignTokens.Typography.caption)
                    .foregroundStyle(DesignTokens.Color.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct OWSettingsLabeledRow: View {
    let label: String
    let value: String

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text(label)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textSecondary)
            Spacer(minLength: DesignTokens.Spacing.spacing3)
            Text(value)
                .font(DesignTokens.Typography.caption)
                .foregroundStyle(DesignTokens.Color.textPrimary)
                .multilineTextAlignment(.trailing)
        }
    }
}
