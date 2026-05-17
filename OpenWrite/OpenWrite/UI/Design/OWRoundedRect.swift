import SwiftUI

// MARK: - OWRoundedRect

enum OWRoundedRectStyle {
    case surface
    case elevated
    case editorPanel
    case sidebarCard
}

/// Canonical OW Rect surface — see docs/design/OWComponents.md.
struct OWRoundedRect<Content: View>: View {
    let style: OWRoundedRectStyle
    let padding: CGFloat
    @ViewBuilder let content: () -> Content

    init(
        style: OWRoundedRectStyle = .surface,
        padding: CGFloat = DesignTokens.Spacing.spacing3,
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.style = style
        self.padding = padding
        self.content = content
    }

    var body: some View {
        content()
            .padding(padding)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(fillColor, in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay {
                if showsBorder {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .strokeBorder(borderColor, lineWidth: borderWidth)
                }
            }
            .modifier(ShadowModifier(style: style))
    }

    private var cornerRadius: CGFloat {
        switch style {
        case .editorPanel:
            return DesignTokens.Radius.large
        default:
            return DesignTokens.Radius.owRect
        }
    }

    private var fillColor: Color {
        switch style {
        case .surface:
            return DesignTokens.Color.surface
        case .elevated:
            return DesignTokens.Color.surfaceElevated
        case .editorPanel:
            return DesignTokens.Color.editorCanvas
        case .sidebarCard:
            return DesignTokens.Color.surfaceElevated.opacity(0.72)
        }
    }

    private var showsBorder: Bool {
        switch style {
        case .surface, .sidebarCard:
            return false
        case .elevated, .editorPanel:
            return true
        }
    }

    private var borderColor: Color {
        switch style {
        case .editorPanel:
            return DesignTokens.Color.borderHairline
        default:
            return DesignTokens.Color.borderSubtle
        }
    }

    private var borderWidth: CGFloat {
        switch style {
        case .editorPanel:
            return 0.5
        default:
            return DesignTokens.Layout.borderWidth
        }
    }

    private struct ShadowModifier: ViewModifier {
        let style: OWRoundedRectStyle

        func body(content: Self.Content) -> some View {
            switch style {
            case .elevated:
                let spec = DesignTokens.Shadow.subtle
                content.shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
            case .editorPanel:
                let spec = DesignTokens.Shadow.subtle
                content.shadow(color: spec.color.opacity(0.65), radius: spec.radius + 2, x: spec.x, y: spec.y + 1)
            default:
                content
            }
        }
    }
}
