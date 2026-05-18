import AppKit
import SwiftUI

// MARK: - OpenWrite Design Tokens
// Canonical implementation of docs/design/Tokens.md and related design docs.
// Use semantic names in views; do not hard-code spacing or hex colors.

enum DesignTokens {

    // MARK: Color

    enum Color {
        private static var palette: ThemePalette { ThemeManager.shared.palette }

        // MARK: Backgrounds & surfaces

        static var background: SwiftUI.Color { palette.background }

        /// Left nav rail — slightly cooler than the workbench chrome for contrast.
        static var sidebarBackground: SwiftUI.Color { palette.sidebarBackground }

        /// Outer split padding behind the elevated editor card.
        static var workbenchChrome: SwiftUI.Color { palette.workbenchChrome }

        /// Filled top title/toolbar region behind traffic lights.
        static var shellChrome: SwiftUI.Color { palette.shellChrome }

        /// Main writing column.
        static var editorCanvas: SwiftUI.Color { palette.editorCanvas }

        /// Hairline borders on elevated cards (softer than `borderSubtle`).
        static var borderHairline: SwiftUI.Color { palette.borderHairline }

        static var surface: SwiftUI.Color { palette.surface }

        static var surfaceElevated: SwiftUI.Color { palette.surfaceElevated }

        /// Sidebar row pill when selected.
        static var selectionPill: SwiftUI.Color { palette.selectionPill }
        static var selectionHighlight: SwiftUI.Color { palette.selectionHighlight }

        static var borderSubtle: SwiftUI.Color { palette.borderSubtle }

        // MARK: Text

        static var textPrimary: SwiftUI.Color { palette.textPrimary }

        static var textSecondary: SwiftUI.Color { palette.textSecondary }

        static var textTertiary: SwiftUI.Color { palette.textTertiary }

        // MARK: Brand & semantic

        static var accent: SwiftUI.Color { palette.accent }

        static var accentMuted: SwiftUI.Color { palette.accentMuted }

        static var separator: SwiftUI.Color { palette.separator }

        static var danger: SwiftUI.Color { palette.danger }

        static var dangerMuted: SwiftUI.Color { palette.dangerMuted }

        static var success: SwiftUI.Color { palette.success }

        static var warning: SwiftUI.Color { palette.warning }

        // MARK: Editor & graph

        static var wikilink: SwiftUI.Color { palette.wikilink }

        static var codeBackground: SwiftUI.Color { palette.codeBackground }

        static var graphNode: SwiftUI.Color { palette.graphNode }

        static var graphEdge: SwiftUI.Color { palette.graphEdge }

        static var graphNodeFocused: SwiftUI.Color { palette.graphNodeFocused }

        // MARK: Private

        fileprivate static func adaptive(
            light: (CGFloat, CGFloat, CGFloat),
            dark: (CGFloat, CGFloat, CGFloat)
        ) -> SwiftUI.Color {
            SwiftUI.Color(nsColor: NSColor(name: nil) { appearance in
                let rgb = appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua ? dark : light
                return NSColor(srgbRed: rgb.0, green: rgb.1, blue: rgb.2, alpha: 1)
            })
        }
    }

    // MARK: Object type accents

    enum ObjectType {
        static func accent(for pageType: PageType) -> SwiftUI.Color {
            switch pageType {
            case .note:
                return Color.adaptive(light: (0.23, 0.42, 0.88), dark: (0.40, 0.58, 0.95))
            case .task:
                return Color.adaptive(light: (0.92, 0.45, 0.18), dark: (0.98, 0.58, 0.32))
            case .reference:
                return Color.adaptive(light: (0.55, 0.35, 0.85), dark: (0.68, 0.50, 0.92))
            case .journal:
                return Color.adaptive(light: (0.22, 0.62, 0.42), dark: (0.38, 0.75, 0.55))
            case .project:
                return Color.adaptive(light: (0.35, 0.38, 0.82), dark: (0.48, 0.52, 0.90))
            case .book:
                return Color.adaptive(light: (0.55, 0.40, 0.28), dark: (0.72, 0.58, 0.42))
            case .document:
                return Color.adaptive(light: (0.18, 0.58, 0.58), dark: (0.32, 0.72, 0.72))
            case .wikiSite:
                return Color.adaptive(light: (0.20, 0.62, 0.78), dark: (0.35, 0.75, 0.88))
            case .collection:
                return Color.adaptive(light: (0.50, 0.52, 0.56), dark: (0.62, 0.64, 0.68))
            }
        }

        static func chipBackground(for pageType: PageType) -> SwiftUI.Color {
            accent(for: pageType).opacity(0.14)
        }

        /// Sidebar / banner icon wells — stronger than chip wash.
        static func wellBackground(for pageType: PageType) -> SwiftUI.Color {
            accent(for: pageType).opacity(0.28)
        }
    }

    // MARK: Opacity

    enum Opacity {
        static let overlayLight: Double = 0.04
        static let overlayMedium: Double = 0.08
        static let overlayStrong: Double = 0.12
        static let scrim: Double = 0.35
        static let focusRing: Double = 0.40
        static let pillSelected: Double = 1.0
    }

    // MARK: Typography
    // Bundled Source Serif 4 — see docs/design/Typography.md and OWTypography.swift

    enum Typography {
        typealias Scale = OWTypography.Scale

        static let documentTitle = OWTypography.documentTitle
        static let documentTitleLineSpacing = OWTypography.documentTitleLineSpacing
        static let heading1 = OWTypography.heading1
        static let heading1LineSpacing = OWTypography.heading1LineSpacing
        static let heading2 = OWTypography.heading2
        static let heading2LineSpacing = OWTypography.heading2LineSpacing
        static let heading3 = OWTypography.heading3
        static let heading3LineSpacing = OWTypography.heading3LineSpacing
        static let body = OWTypography.body
        static let bodyLineSpacing = OWTypography.bodyLineSpacing
        static let bodyEmphasis = OWTypography.bodyEmphasis
        static let panelTitle = OWTypography.panelTitle
        static let subheadlineEmphasis = OWTypography.subheadlineEmphasis
        static let callout = OWTypography.callout
        static let calloutEmphasis = OWTypography.calloutEmphasis
        static let caption = OWTypography.caption
        static let captionEmphasis = OWTypography.captionEmphasis
        static let caption2 = OWTypography.caption2
        static let footnote = OWTypography.footnote
        static let code = OWTypography.code
        static let codeSmall = OWTypography.codeSmall
        static let sidebarItem = OWTypography.sidebarItem
        static let sidebarItemEmphasis = OWTypography.sidebarItemEmphasis
        static let sidebarSection = OWTypography.sidebarSection
        static let railSectionLabel = OWTypography.railSectionLabel
        static let railSectionTracking = OWTypography.railSectionTracking
        static let toolbarLabel = OWTypography.toolbarLabel
        static let pageTypeIcon = OWTypography.pageTypeIcon
        static let sidebarWellIcon = OWTypography.sidebarWellIcon
        static let heroSymbol = OWTypography.heroSymbol
        static var editorNSFont: NSFont { OWTypography.editorNSFont }
        static var editorParagraphStyle: NSParagraphStyle { OWTypography.editorParagraphStyle }
        static var editorTypingAttributes: [NSAttributedString.Key: Any] { OWTypography.editorTypingAttributes }
        static var isBundledSerifAvailable: Bool { OWTypography.isBundledSerifAvailable }
        static let bundledSerifMissingMessage = OWTypography.bundledSerifMissingMessage
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
            top: spacing4, leading: spacing5, bottom: spacing4, trailing: spacing5
        )
        /// Hero / header band inside the editor card — tighter than full editor padding.
        static let editorHeroPadding = EdgeInsets(
            top: spacing2, leading: spacing3, bottom: spacing1, trailing: spacing3
        )
        static let sidebarPadding = EdgeInsets(
            top: spacing3, leading: spacing3, bottom: spacing4, trailing: spacing3
        )
        static let sidebarRowSubtitleSpacing: CGFloat = spacing1
        static let inspectorPadding = EdgeInsets(
            top: spacing4, leading: spacing4, bottom: spacing4, trailing: spacing4
        )
        /// Chat, related, and past-writes columns in the assist strip.
        static let assistStripContentPadding = EdgeInsets(
            top: spacing3, leading: spacing3, bottom: spacing3, trailing: spacing3
        )
        /// Message list in chat — tighter bottom gap above the composer inset.
        static let assistStripMessageListPadding = EdgeInsets(
            top: spacing3, leading: spacing3, bottom: spacing2, trailing: spacing3
        )
        /// Chat composer footer — less vertical chrome than generic strip padding.
        static let assistStripComposerPadding = EdgeInsets(
            top: spacing2, leading: spacing3, bottom: spacing2, trailing: spacing3
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
        /// OW Rect — sidebar selection, CTAs, modals, toolbar actions (canonical tier).
        static let owRect: CGFloat = 11
        static let large: CGFloat = 12
        /// Metadata / type chips under the page title.
        static let metadataChip: CGFloat = 10
        /// Alias — prefer `owRect` for new surfaces.
        static let shellCard: CGFloat = owRect
        static let toolbarAction: CGFloat = owRect
        static let xlarge: CGFloat = 16
        static let pill: CGFloat = 9999
        static let full: CGFloat = pill
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
        static let sidebarMaxWidth: CGFloat = 320
        static let sidebarPreferredWidth: CGFloat = 260
        /// Collapsed navigation rail — icon-only column.
        static let navigationRailCollapsedWidth: CGFloat = 48
        /// Legacy fixed width — prefer persisted `ShellChromePreferences.navigationRailWidth`.
        static let navigationRailWidth: CGFloat = sidebarPreferredWidth
        static let sidebarRowHeight: CGFloat = 40
        static let sidebarRowMinHeight: CGFloat = 40
        static let sidebarRowTallMinHeight: CGFloat = 52
        static let sidebarRowIconSize: CGFloat = 18
        static let objectIconWellSize: CGFloat = 28
        static let sidebarBottomButtonSize: CGFloat = 32
        static let graphFloatingBarMaxWidth: CGFloat = 560
        static let objectTypeChipHeight: CGFloat = 24
        /// Center workbench column (editor + graph card) — absorbs horizontal growth.
        static let editorMinWidth: CGFloat = 400
        /// Minimum share of the center workbench when the assist strip is open (ProductDirection).
        static let editorMinWidthFraction: CGFloat = 0.55
        /// Slim Reor-style assist strip — secondary to the editor column.
        static let assistStripMinWidth: CGFloat = 240
        static let assistStripMaxWidth: CGFloat = 360
        static let assistStripDefaultWidth: CGFloat = 280
        static let assistStripCollapsedWidth: CGFloat = 44
        /// Below this measured strip width, composer toggles show icon-only switches.
        static let assistStripIconsOnlyThreshold: CGFloat = 268
        /// Hysteresis before auto-collapsing assist on window shrink (avoids flicker on minor resize).
        static let assistCollapseHysteresis: CGFloat = 40
        /// Smaller editor floor when assist is open so the strip can narrow before collapsing.
        static let editorMinWidthWhenAssistOpen: CGFloat = 360
        static let editorMinWidthWhenAssistFraction: CGFloat = 0.42
        static let inspectorMinWidth: CGFloat = assistStripMinWidth
        static let inspectorIdealWidth: CGFloat = 280
        static let inspectorMaxWidth: CGFloat = assistStripMaxWidth
        static let assistBottomBarHeight: CGFloat = 32
        static let assistStripComposerBottomInset: CGFloat = Spacing.spacing2
        /// Chat composer attach / send / stop / toggle cell size (2×2 board beside field).
        static let composerActionSize: CGFloat = 36
        /// Gap between cells in the composer 2×2 action board.
        static let composerBoardSpacing: CGFloat = Spacing.spacing1
        /// Height of the 2×2 action board (field min height aligns to this).
        static var composerBoardHeight: CGFloat { composerActionSize * 2 + composerBoardSpacing }
        /// Inner text inset for multiline composer (clears left edge of field chrome).
        static let composerFieldLeadingInset: CGFloat = Spacing.spacing3
        static let composerFieldTrailingInset: CGFloat = Spacing.spacing2
        /// Glyph size for composer 2×2 board icons (Notes, Web, attach, send).
        static let composerBoardIconSize: CGFloat = 18
        /// Max height for multiline chat composer before internal scroll.
        static let composerFieldMaxHeight: CGFloat = 120
        static let centerCardOuterPadding: CGFloat = Spacing.spacing2
        static let shellColumnGutter: CGFloat = Spacing.spacing2
        /// Below this width, collapse assist before shrinking editor (see LayoutAndResize.md).
        static let mainMinWidth: CGFloat = editorMinWidth + assistStripMinWidth
        static let windowMinWidth: CGFloat = 900
        static let windowMinHeight: CGFloat = 600
        static let windowDefaultWidth: CGFloat = 1200
        static let windowDefaultHeight: CGFloat = 800
        /// Shell chrome switches to compact title + tighter graph hero below this width.
        static let shellCompactBreakpoint: CGFloat = 1100
        /// Auto-collapse assist when the center workbench cannot satisfy editor + assist mins.
        static let shellTightBreakpoint: CGFloat = 980
        static let graphEmptyStateCompactWidth: CGFloat = 520
        static let graphEmptyStateMaxReadableWidth: CGFloat = 420
        /// Reserve above bottom graph chrome so empty-state hero does not overlap controls.
        static let graphChromeBottomReserve: CGFloat = 88
        static let graphChromeTopReserve: CGFloat = 24
        /// Optional readable measure cap (settings / empty states). Editor body fills the column by default.
        static let editorMaxContentWidth: CGFloat = 880
        /// Single leading gutter for page title, metadata, toolbars, and block text (Anytype-style column).
        static let editorContentLeadingInset: CGFloat = Spacing.spacing3
        /// Trailing/top inset for header overlay controls (page options) inside the clipped editor card.
        static let editorChromePadding: CGFloat = Spacing.spacing3
        /// Top inset clearing `Radius.large` on the editor panel when controls sit on the cover strip.
        static let editorChromeTopInset: CGFloat = Radius.large + Spacing.spacing1
        /// Extra leading inset on list block cards so bullets/checkboxes clear the card edge.
        static let blockCardListExtraLeadingInset: CGFloat = Spacing.spacing1
        /// Vertical gap between page header stack and block list.
        static let editorHeaderToBodySpacing: CGFloat = Spacing.spacing4
        /// Vertical gap between block rows in the WYSIWYG editor.
        static let editorBlockStackSpacing: CGFloat = Spacing.spacing2
        static let editorMetadataToToolbarSpacing: CGFloat = Spacing.spacing3
        static let captureSheetWidth: CGFloat = 520
        static let captureSheetMinHeight: CGFloat = 200
        static let graphNodeMinSize: CGFloat = 44
        /// Anytype-style graph node card (icon + label).
        static let graphNodeCardWidth: CGFloat = 120
        static let graphNodeCardHeight: CGFloat = 56
        static let graphNodeMinSpacing: CGFloat = 20
        static let toolbarHeight: CGFloat = 52
        /// Inset below traffic lights for custom title bar content.
        static let shellChromeSafeAreaTop: CGFloat = 28
        /// Title + tabs row inside the filled chrome strip.
        static let shellChromeBarHeight: CGFloat = 44
        /// Leading inset clearing traffic-light cluster (inset from window edge).
        static let shellChromeContentLeadingInset: CGFloat = 78
        /// Slightly tighter inset when the window is below `shellCompactBreakpoint`.
        static let shellChromeCompactLeadingInset: CGFloat = 72
        /// Aligns shell brand text with `OWSidebarSectionHeader` labels inside the navigation rail.
        static var navigationRailBrandLeadingInset: CGFloat {
            Spacing.sidebarPadding.leading + Spacing.spacing2 + 20 + Spacing.spacing1
        }
        /// Fixed leading gutter for callout icon + type control (matches quote bar density).
        static let calloutLeadingGutter: CGFloat = 22
        static let splitDividerHitWidth: CGFloat = 6
        static let focusRingWidth: CGFloat = 2
        static let quoteBarWidth: CGFloat = 3
        static let borderWidth: CGFloat = 1
    }
}

// MARK: - View helpers

extension View {
    func openWriteFloatingShadow() -> some View {
        let spec = DesignTokens.Shadow.floating
        return shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }

    /// Centers readable editor content in the workbench column (cover/banner may stay full bleed outside this).
    func openWriteEditorContentWidth(
        alignment: Alignment = .center,
        readableMaxWidth: CGFloat = DesignTokens.Layout.editorMaxContentWidth
    ) -> some View {
        frame(maxWidth: readableMaxWidth, alignment: alignment)
            .frame(maxWidth: .infinity, alignment: alignment)
    }

    /// Full-bleed width inside the editor card (empty states that need edge-to-edge chrome).
    func openWriteEditorFullWidth(alignment: Alignment = .leading) -> some View {
        frame(maxWidth: .infinity, alignment: alignment)
    }

    /// Applies the canonical editor column leading/trailing inset (use once per row — not on scroll + blocks).
    func openWriteEditorLeadingInset() -> some View {
        padding(.horizontal, DesignTokens.Layout.editorContentLeadingInset)
    }

    /// Full-width editor canvas; content is responsible for its own vertical scroll when needed.
    func openWriteEditorColumn<Content: View>(
        canvasColor: Color,
        @ViewBuilder content: () -> Content
    ) -> some View {
        content()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .background(canvasColor)
    }

    func owRect(
        style: OWRoundedRectStyle = .surface,
        padding: CGFloat = DesignTokens.Spacing.spacing3
    ) -> some View {
        OWRoundedRect(style: style, padding: padding) {
            self
        }
    }
}
