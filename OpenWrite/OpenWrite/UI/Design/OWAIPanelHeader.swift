import SwiftUI

// MARK: - OWAIPanelHeader

/// Inspector / assist-strip AI chrome — title, back when depth ≥ 1, trailing actions.
/// See `docs/design/OWComponents.md` and `docs/design/ProductDirection.md` (AI panels).
struct OWAIPanelHeader<Center: View, Trailing: View>: View {
    let title: String
    var canGoBack: Bool
    var backAccessibilityLabel: String?
    var onBack: (() -> Void)?
    var compact: Bool
    var showsSeparator: Bool
    private let useTitleCenter: Bool
    @ViewBuilder private var center: () -> Center
    @ViewBuilder private var trailing: () -> Trailing

    init(
        title: String,
        canGoBack: Bool = false,
        backAccessibilityLabel: String? = nil,
        onBack: (() -> Void)? = nil,
        compact: Bool = false,
        showsSeparator: Bool = true,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) where Center == EmptyView {
        self.title = title
        self.canGoBack = canGoBack
        self.backAccessibilityLabel = backAccessibilityLabel
        self.onBack = onBack
        self.compact = compact
        self.showsSeparator = showsSeparator
        self.useTitleCenter = true
        self.center = { EmptyView() }
        self.trailing = trailing
    }

    init(
        title: String,
        canGoBack: Bool = false,
        backAccessibilityLabel: String? = nil,
        onBack: (() -> Void)? = nil,
        compact: Bool = false,
        showsSeparator: Bool = true,
        @ViewBuilder center: @escaping () -> Center,
        @ViewBuilder trailing: @escaping () -> Trailing = { EmptyView() }
    ) {
        self.title = title
        self.canGoBack = canGoBack
        self.backAccessibilityLabel = backAccessibilityLabel
        self.onBack = onBack
        self.compact = compact
        self.showsSeparator = showsSeparator
        self.useTitleCenter = false
        self.center = center
        self.trailing = trailing
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: DesignTokens.Spacing.spacing2) {
                if canGoBack, let onBack {
                    Button(action: onBack) {
                        OWIconView(icon: .back, size: 14)
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(DesignTokens.Color.textSecondary)
                    .accessibilityLabel(backAccessibilityLabel ?? "Back")
                }

                Group {
                    if useTitleCenter {
                        Text(title)
                            .font(OWTypography.calloutEmphasis)
                            .foregroundStyle(DesignTokens.Color.textPrimary)
                            .lineLimit(1)
                    } else {
                        center()
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                trailing()
            }
            .padding(.horizontal, DesignTokens.Spacing.spacing3)
            .padding(.vertical, compact ? DesignTokens.Spacing.spacing1 : DesignTokens.Spacing.spacing2)
            .frame(minHeight: compact ? 44 : DesignTokens.Layout.toolbarHeight)

            if showsSeparator {
                Divider()
            }
        }
    }
}

// MARK: - Keyboard back (inspector / assist focus)

struct AIAssistKeyboardBackModifier: ViewModifier {
    @ObservedObject var navigation: AIAssistNavigationState

    func body(content: Content) -> some View {
        content
            .onKeyPress(.escape) {
                guard navigation.stripCanGoBack else { return .ignored }
                navigation.stripBack()
                return .handled
            }
            .onKeyPress(keys: ["["]) { press in
                guard press.modifiers.contains(.command), navigation.stripCanGoBack else { return .ignored }
                navigation.stripBack()
                return .handled
            }
    }
}

extension View {
    func aiAssistKeyboardBack(_ navigation: AIAssistNavigationState) -> some View {
        modifier(AIAssistKeyboardBackModifier(navigation: navigation))
    }
}
