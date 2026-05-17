import AppKit
import SwiftUI

// MARK: - OpenWrite Design Tokens
// Canonical implementation of docs/design/Tokens.md and related design docs.
// Use semantic names in views; do not hard-code spacing or hex colors.

enum DesignTokens {

    // MARK: Color

    enum Color {
        // MARK: Backgrounds & surfaces

        static var background: SwiftUI.Color {
            adaptive(light: (0.98, 0.98, 0.97), dark: (0.11, 0.11, 0.12))
        }

        static var surface: SwiftUI.Color {
            adaptive(light: (0.95, 0.95, 0.94), dark: (0.15, 0.15, 0.16))
        }

        static var surfaceElevated: SwiftUI.Color {
            adaptive(light: (1.0, 1.0, 1.0), dark: (0.18, 0.18, 0.19))
        }

        // MARK: Text

        static var textPrimary: SwiftUI.Color {
            adaptive(light: (0.10, 0.10, 0.10), dark: (0.95, 0.95, 0.96))
        }

        static var textSecondary: SwiftUI.Color {
            adaptive(light: (0.45, 0.45, 0.47), dark: (0.62, 0.62, 0.64))
        }

        static var textTertiary: SwiftUI.Color {
            adaptive(light: (0.60, 0.60, 0.62), dark: (0.48, 0.48, 0.50))
        }

        // MARK: Brand & semantic

        /// Matches Assets.xcassets AccentColor (~sRGB 58, 107, 224).
        static var accent: SwiftUI.Color {
            adaptive(light: (0.227, 0.420, 0.878), dark: (0.35, 0.55, 0.95))
        }

        static var accentMuted: SwiftUI.Color {
            accent.opacity(0.14)
        }

        static var separator: SwiftUI.Color {
            adaptive(light: (0.88, 0.88, 0.87), dark: (0.28, 0.28, 0.30))
        }

        static var danger: SwiftUI.Color {
            adaptive(light: (0.85, 0.22, 0.24), dark: (0.95, 0.35, 0.38))
        }

        static var dangerMuted: SwiftUI.Color {
            danger.opacity(0.12)
        }

        static var success: SwiftUI.Color {
            adaptive(light: (0.20, 0.62, 0.38), dark: (0.35, 0.75, 0.50))
        }

        static var warning: SwiftUI.Color {
            adaptive(light: (0.85, 0.55, 0.12), dark: (0.95, 0.70, 0.25))
        }

        // MARK: Editor & graph

        static var wikilink: SwiftUI.Color { accent }

        static var codeBackground: SwiftUI.Color { surface }

        static var graphNode: SwiftUI.Color { surfaceElevated }

        static var graphEdge: SwiftUI.Color { textTertiary }

        static var graphNodeFocused: SwiftUI.Color { accent }

        // MARK: Private

        private static func adaptive(
            light: (CGFloat, CGFloat, CGFloat),
            dark: (CGFloat, CGFloat, CGFloat)
        ) -> SwiftUI.Color {
            SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
                let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
                return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
            })
        }
    }

    // MARK: Opacity

    enum Opacity {
        static let overlayLight: Double = 0.04
        static let overlayMedium: Double = 0.08
        static let overlayStrong: Double = 0.12
        static let scrim: Double = 0.35
        static let focusRing: Double = 0.40
    }

    // MARK: Typography

    enum Typography {
        static let documentTitle = Font.largeTitle.bold()
        static let heading1 = Font.title.weight(.semibold)
        static let heading2 = Font.title2.weight(.semibold)
        static let heading3 = Font.title3.weight(.medium)
        static let body = Font.body
        static let bodyEmphasis = Font.body.weight(.medium)
        static let callout = Font.callout
        static let caption = Font.caption
        static let captionEmphasis = Font.caption.weight(.medium)
        static let footnote = Font.footnote
        static let code = Font.system(.body, design: .monospaced)
        static let codeSmall = Font.system(.callout, design: .monospaced)
        static let sidebarItem = Font.body
        static let sidebarSection = Font.caption.weight(.semibold)
        static let toolbarLabel = Font.callout
    }

    // MARK: Spacing (4pt grid)

    enum Spacing {
        static let spacing0: CGFloat = 0
        static let spacing1: CGFloat = 4
        static let spacing2: CGFloat = 8
        static let spacing3: CGFloat = 12
        static let spacing4: CGFloat = 16
        static let spacing5: CGFloat = 20
        static let spacing6: CGFloat = 24
        static let spacing7: CGFloat = 28
        static let spacing8: CGFloat = 32
        static let spacing10: CGFloat = 40
        static let spacing12: CGFloat = 48

        static let editorPadding = EdgeInsets(
            top: spacing6, leading: spacing6, bottom: spacing6, trailing: spacing6
        )
        static let sidebarPadding = EdgeInsets(
            top: spacing2, leading: spacing4, bottom: spacing2, trailing: spacing4
        )
        static let inspectorPadding = EdgeInsets(
            top: spacing4, leading: spacing4, bottom: spacing4, trailing: spacing4
        )
        static let captureSheetPadding = EdgeInsets(
            top: spacing6, leading: spacing6, bottom: spacing6, trailing: spacing6
        )
    }

    // MARK: Radius

    enum Radius {
        static let none: CGFloat = 0
        static let small: CGFloat = 6
        static let medium: CGFloat = 8
        static let large: CGFloat = 12
        static let xlarge: CGFloat = 16
        static let full: CGFloat = 9999
    }

    // MARK: Shadow

    enum Shadow {
        struct Spec {
            let color: SwiftUI.Color
            let radius: CGFloat
            let x: CGFloat
            let y: CGFloat
        }

        static let none = Spec(color: .clear, radius: 0, x: 0, y: 0)

        static var subtle: Spec {
            Spec(color: SwiftUI.Color.black.opacity(0.08), radius: 4, x: 0, y: 1)
        }

        static var floating: Spec {
            Spec(color: SwiftUI.Color.black.opacity(0.12), radius: 16, x: 0, y: 4)
        }

        static var elevated: Spec {
            Spec(color: SwiftUI.Color.black.opacity(0.16), radius: 24, x: 0, y: 8)
        }
    }

    // MARK: Motion

    enum Motion {
        static let durationInstant: Double = 0.08
        static let durationFast: Double = 0.15
        static let durationStandard: Double = 0.22
        static let durationSlow: Double = 0.32
        static let durationEmphasis: Double = 0.45

        static var animationStandard: Animation {
            .easeInOut(duration: durationStandard)
        }

        static var animationFast: Animation {
            .easeInOut(duration: durationFast)
        }

        static var animationSlow: Animation {
            .easeOut(duration: durationSlow)
        }

        static var springSnappy: Animation {
            .spring(response: 0.28, dampingFraction: 0.86)
        }

        static var springGentle: Animation {
            .spring(response: 0.38, dampingFraction: 0.92)
        }

        /// Returns nil when reduced motion is enabled — use for optional animations.
        static func animation(_ standard: Animation, reduceMotion: Bool) -> Animation? {
            reduceMotion ? nil : standard
        }
    }

    // MARK: Layout

    enum Layout {
        static let sidebarMinWidth: CGFloat = 220
        static let sidebarMaxWidth: CGFloat = 280
        static let inspectorMinWidth: CGFloat = 280
        static let inspectorMaxWidth: CGFloat = 360
        static let mainMinWidth: CGFloat = 480
        static let editorMaxContentWidth: CGFloat = 720
        static let captureSheetWidth: CGFloat = 520
        static let captureSheetMinHeight: CGFloat = 200
        static let graphNodeMinSize: CGFloat = 44
        static let toolbarHeight: CGFloat = 52
        static let focusRingWidth: CGFloat = 2
        static let quoteBarWidth: CGFloat = 3
    }
}

// MARK: - View helpers

extension View {
    func openWriteFloatingShadow() -> some View {
        let spec = DesignTokens.Shadow.floating
        return shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }

    func openWriteEditorContentWidth() -> some View {
        frame(maxWidth: DesignTokens.Layout.editorMaxContentWidth)
            .frame(maxWidth: .infinity)
    }
}
