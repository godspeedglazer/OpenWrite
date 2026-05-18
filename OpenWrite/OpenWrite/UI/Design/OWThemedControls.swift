import SwiftUI

// MARK: - Focus chrome

/// How OpenWrite handles macOS keyboard focus rings on SwiftUI controls.
enum OpenWriteFocusChromePolicy {
    /// No system blue ring; control is not in the tab order (icon rails, segments, popover rows).
    case hidden
    /// No system ring; keeps default tab order (fields that draw their own accent outline).
    case suppressSystemRing
    /// No system ring; subtle accent outline when keyboard-focused (primary sheet / capsule actions).
    case themedKeyboard
}

extension View {
    /// Replaces the default macOS focus highlight with OpenWrite policy (see `OpenWriteFocusChromePolicy`).
    func openWriteFocusChrome(_ policy: OpenWriteFocusChromePolicy = .hidden) -> some View {
        modifier(OpenWriteFocusChromeModifier(policy: policy))
    }

    /// Accent keyboard focus ring for custom `ButtonStyle` labels (`Capsule`, `RoundedRectangle`, etc.).
    func openWriteButtonKeyboardFocus<S: InsettableShape>(in shape: S) -> some View {
        modifier(OpenWriteButtonKeyboardFocusModifier(shape: shape))
    }

    /// macOS sheet window background — cream `background` token, not system white.
    func openWriteSheetPresentationChrome() -> some View {
        presentationBackground(DesignTokens.Color.background)
    }
}

private struct OpenWriteFocusChromeModifier: ViewModifier {
    let policy: OpenWriteFocusChromePolicy
    @FocusState private var isKeyboardFocused: Bool

    func body(content: Content) -> some View {
        switch policy {
        case .hidden:
            content
                .focusable(false)
                .modifier(OpenWriteSuppressSystemFocusEffectModifier())
        case .suppressSystemRing:
            content
                .modifier(OpenWriteSuppressSystemFocusEffectModifier())
        case .themedKeyboard:
            content
                .focusable()
                .focused($isKeyboardFocused)
                .modifier(OpenWriteSuppressSystemFocusEffectModifier())
                .overlay {
                    OpenWriteKeyboardFocusRing(isVisible: isKeyboardFocused)
                }
        }
    }
}

private struct OpenWriteButtonKeyboardFocusModifier<S: InsettableShape>: ViewModifier {
    let shape: S
    @FocusState private var isKeyboardFocused: Bool

    func body(content: Content) -> some View {
        content
            .focusable()
            .focused($isKeyboardFocused)
            .modifier(OpenWriteSuppressSystemFocusEffectModifier())
            .overlay {
                shape
                    .strokeBorder(
                        DesignTokens.Color.accent.opacity(DesignTokens.Opacity.focusRing),
                        lineWidth: DesignTokens.Layout.focusRingWidth
                    )
                    .allowsHitTesting(false)
                    .opacity(isKeyboardFocused ? 1 : 0)
            }
    }
}

private struct OpenWriteKeyboardFocusRing: View {
    var isVisible: Bool
    var cornerRadius: CGFloat = DesignTokens.Radius.owRect

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .strokeBorder(
                DesignTokens.Color.accent.opacity(DesignTokens.Opacity.focusRing),
                lineWidth: DesignTokens.Layout.focusRingWidth
            )
            .allowsHitTesting(false)
            .opacity(isVisible ? 1 : 0)
    }
}

private struct OpenWriteSuppressSystemFocusEffectModifier: ViewModifier {
    @ViewBuilder
    func body(content: Content) -> some View {
        if #available(macOS 14.0, *) {
            content.focusEffectDisabled()
        } else {
            content
        }
    }
}

// MARK: - Settings sheet chrome

/// Themed settings / modal shell — `shellChrome` header, `background` body, accent Done.
struct OWSettingsSheet<Content: View>: View {
    let title: String
    var dismissButtonTitle: String = "Done"
    var dismissButtonUsesSecondaryStyle: Bool = false
    let onDone: () -> Void
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.spacing3) {
                Text(title)
                    .font(DesignTokens.Typography.heading3)
                    .foregroundStyle(DesignTokens.Color.textPrimary)
                Spacer(minLength: 0)
                dismissButton
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
        .openWriteSheetPresentationChrome()
    }

    @ViewBuilder
    private var dismissButton: some View {
        if dismissButtonUsesSecondaryStyle {
            Button(dismissButtonTitle, action: onDone)
                .buttonStyle(OWSecondaryRectButtonStyle())
        } else {
            Button(dismissButtonTitle, action: onDone)
                .buttonStyle(OWAccentCapsuleButtonStyle())
        }
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
            .openWriteButtonKeyboardFocus(in: Capsule())
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
            .openWriteButtonKeyboardFocus(in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous))
    }
}

/// Composer attach / secondary actions — square cell in the 2×2 board (`owRect`).
struct OWComposerIconButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: DesignTokens.Layout.composerActionSize, height: DesignTokens.Layout.composerActionSize)
            .background(
                DesignTokens.Color.surface.opacity(configuration.isPressed ? 0.85 : 1),
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
            }
            .openWriteFocusChrome()
    }
}

/// Primary send — accent fill, up-arrow glyph.
struct OWComposerSendButtonStyle: ButtonStyle {
    var isEnabled: Bool = true

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: DesignTokens.Layout.composerActionSize, height: DesignTokens.Layout.composerActionSize)
            .background(
                DesignTokens.Color.accent.opacity(
                    !isEnabled ? 0.35 : (configuration.isPressed ? 0.82 : 1)
                ),
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
            )
            .openWriteFocusChrome()
    }
}

/// Stop in-flight chat stream — muted surface, same footprint as send.
struct OWComposerStopButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .frame(width: DesignTokens.Layout.composerActionSize, height: DesignTokens.Layout.composerActionSize)
            .background(
                DesignTokens.Color.surfaceElevated.opacity(configuration.isPressed ? 0.8 : 0.95),
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                    .strokeBorder(DesignTokens.Color.warning.opacity(0.45), lineWidth: DesignTokens.Layout.borderWidth)
            }
            .openWriteFocusChrome()
    }
}

/// Compact icon action for chat composer / panel chrome (surface, not system white).
struct OWThemedIconButtonStyle: ButtonStyle {
    var isProminent: Bool = false

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .padding(6)
            .background(
                isProminent
                    ? DesignTokens.Color.accentMuted.opacity(configuration.isPressed ? 0.7 : 1)
                    : DesignTokens.Color.surface.opacity(configuration.isPressed ? 0.85 : 1),
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
                    .strokeBorder(
                        isProminent ? DesignTokens.Color.accent.opacity(0.35) : DesignTokens.Color.borderSubtle,
                        lineWidth: DesignTokens.Layout.borderWidth
                    )
            }
            .openWriteFocusChrome()
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
                DesignTokens.Color.surface,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                    .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
            }
            .onSubmit { onSubmit?() }
    }
}

/// Multiline chat composer with themed accent focus ring (no system blue flash).
struct OWThemedComposerField: View {
    let placeholder: String
    @Binding var text: String
    var lineLimit: ClosedRange<Int> = 1 ... 6
    var minHeight: CGFloat = DesignTokens.Layout.composerActionSize
    var onSubmit: (() -> Void)?

    @FocusState private var isFocused: Bool

    var body: some View {
        TextField(placeholder, text: $text, axis: .vertical)
            .textFieldStyle(.plain)
            .font(OWTypography.body)
            .foregroundStyle(DesignTokens.Color.textPrimary)
            .lineLimit(lineLimit)
            .focused($isFocused)
            .openWriteFocusChrome(.suppressSystemRing)
            .frame(
                minHeight: minHeight,
                maxHeight: DesignTokens.Layout.composerFieldMaxHeight,
                alignment: .topLeading
            )
            .padding(.leading, DesignTokens.Layout.composerFieldLeadingInset)
            .padding(.trailing, DesignTokens.Layout.composerFieldTrailingInset)
            .padding(.vertical, DesignTokens.Spacing.spacing2)
            .background(
                DesignTokens.Color.surface,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                    .strokeBorder(
                        isFocused ? DesignTokens.Color.accent.opacity(0.45) : DesignTokens.Color.borderSubtle,
                        lineWidth: isFocused ? DesignTokens.Layout.focusRingWidth : DesignTokens.Layout.borderWidth
                    )
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
    var leadingIconColor: Color?
    /// Icon (+ chevron) trigger without title text — for callout type, narrow rails, etc.
    var iconOnly: Bool = false

    @State private var isOpen = false

    private var resolvedLeadingIconColor: Color {
        leadingIconColor ?? DesignTokens.Color.accent
    }

    var body: some View {
        Button {
            isOpen.toggle()
        } label: {
            Group {
                if iconOnly {
                    ZStack(alignment: .bottomTrailing) {
                        if let leadingIcon {
                            OWUnicodeIconView(
                                icon: leadingIcon,
                                size: compact ? 14 : 16,
                                color: resolvedLeadingIconColor
                            )
                        }
                        OWUnicodeIconView(icon: .chevronDown, size: 7, color: DesignTokens.Color.textTertiary)
                            .offset(x: 3, y: 2)
                    }
                    .frame(width: DesignTokens.Layout.calloutLeadingGutter, height: 18, alignment: .center)
                } else {
                    HStack(spacing: DesignTokens.Spacing.spacing1) {
                        if let leadingIcon {
                            OWUnicodeIconView(
                                icon: leadingIcon,
                                size: compact ? 12 : 14,
                                color: resolvedLeadingIconColor
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
                        DesignTokens.Color.surface,
                        in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                    )
                    .overlay {
                        RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                            .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .accessibilityLabel(accessibilityLabel)
        .popover(isPresented: $isOpen, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
            dropdownList
                .padding(DesignTokens.Spacing.spacing2)
                .background(DesignTokens.Color.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous))
                .overlay {
                    RoundedRectangle(cornerRadius: DesignTokens.Radius.medium, style: .continuous)
                        .strokeBorder(DesignTokens.Color.borderSubtle, lineWidth: DesignTokens.Layout.borderWidth)
                }
                .presentationBackground(DesignTokens.Color.surfaceElevated)
                .onDisappear { isOpen = false }
        }
    }

    private var dropdownList: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: DesignTokens.Spacing.spacing1) {
                ForEach(options, id: \.self) { option in
                    dropdownRow(option)
                }
            }
            .frame(minWidth: max(minWidth, 160), alignment: .leading)
        }
        .scrollBounceBehavior(.basedOnSize)
        .frame(maxHeight: 280)
        .fixedSize(horizontal: false, vertical: true)
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
                isSelected ? DesignTokens.Color.selectionPill : DesignTokens.Color.surface,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
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
                isSelected ? DesignTokens.Color.background : Color.clear,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.small, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .accessibilityLabel(title(option))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

// MARK: - Toggle button

/// Square composer toggle — matches attach/send controls (`owRect`), not an iOS pill switch.
struct OWThemedToggleButton: View {
    let label: String
    @Binding var isOn: Bool
    var icon: OWUnicodeIcon?
    /// When false, renders a fixed 36×36 icon-only square (accessibility / `.help` use `label`).
    var showsLabel: Bool = true
    /// Shorter visible caption in chip layout (accessibility still uses `label`).
    var abbreviatedLabel: String?

    private var visibleLabel: String { abbreviatedLabel ?? label }
    private var actionSize: CGFloat { DesignTokens.Layout.composerActionSize }

    var body: some View {
        Button { isOn.toggle() } label: {
            Group {
                if showsLabel {
                    chipLabel
                } else {
                    iconOnlyLabel
                }
            }
        }
        .buttonStyle(.plain)
        .openWriteFocusChrome()
        .accessibilityLabel(label)
        .accessibilityValue(isOn ? "On" : "Off")
        .accessibilityAddTraits(isOn ? .isSelected : [])
    }

    private var iconOnlyLabel: some View {
        toggleChrome {
            toggleGlyph
                .frame(width: actionSize, height: actionSize)
        }
    }

    private var chipLabel: some View {
        toggleChrome {
            HStack(spacing: DesignTokens.Spacing.spacing2) {
                toggleGlyph
                    .frame(width: actionSize, height: actionSize)
                Text(visibleLabel)
                    .font(OWTypography.caption)
                    .foregroundStyle(
                        isOn ? DesignTokens.Color.textPrimary : DesignTokens.Color.textSecondary
                    )
                    .lineLimit(1)
                    .truncationMode(.tail)
                    .minimumScaleFactor(0.85)
                    .layoutPriority(-1)
            }
            .padding(.trailing, DesignTokens.Spacing.spacing2)
        }
        .frame(height: actionSize)
    }

    @ViewBuilder
    private var toggleGlyph: some View {
        if let icon {
            OWUnicodeIconView(
                icon,
                size: DesignTokens.Layout.composerBoardIconSize,
                color: isOn ? DesignTokens.Color.accent : DesignTokens.Color.textSecondary
            )
        }
    }

    private func toggleChrome<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                isOn ? DesignTokens.Color.accentMuted : DesignTokens.Color.surface,
                in: RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: DesignTokens.Radius.owRect, style: .continuous)
                    .strokeBorder(
                        isOn
                            ? DesignTokens.Color.accent.opacity(0.35)
                            : DesignTokens.Color.borderSubtle,
                        lineWidth: DesignTokens.Layout.borderWidth
                    )
            }
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
