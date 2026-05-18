import AppKit
import CoreText
import SwiftUI

// MARK: - OpenWrite typography roles
// Serifa-inspired serif stack — bundled Source Serif 4 (see docs/design/Typography.md).

enum OWTypography {

    /// Where the face is used in the product — each role maps to the same family with tuned weights.
    enum Role {
        /// Page titles, hero headlines, NDL display headings.
        case display
        /// Sidebar, shell chrome, metadata chips, toolbars.
        case ui
        /// Long-form editor body and preview paragraphs.
        case body
    }

    enum Weight {
        case regular
        case medium
        case semibold
        case bold
    }

    enum Family {
        static let regular = "SourceSerif4-Regular"
        static let semibold = "SourceSerif4-Semibold"
        static let bold = "SourceSerif4-Bold"
    }

    /// Anytype-aligned optical scale (see anytype `common.scss` title/header/body tokens).
    enum Scale {
        static let documentTitle: CGFloat = 36
        static let documentTitleLineHeight: CGFloat = 40
        static let heading1: CGFloat = 28
        static let heading1LineHeight: CGFloat = 32
        static let heading2: CGFloat = 22
        static let heading2LineHeight: CGFloat = 28
        static let heading3: CGFloat = 18
        static let heading3LineHeight: CGFloat = 26
        static let body: CGFloat = 16
        static let bodyLineHeight: CGFloat = 24
        static let callout: CGFloat = 14
        static let calloutLineHeight: CGFloat = 22
        static let sidebarItem: CGFloat = 13
        static let sidebarItemLineHeight: CGFloat = 18
        static let caption: CGFloat = 12
        static let captionLineHeight: CGFloat = 18
        static let caption2: CGFloat = 11
        static let caption2LineHeight: CGFloat = 16
        static let footnote: CGFloat = 11
        static let footnoteLineHeight: CGFloat = 16
        static let pageTypeIcon: CGFloat = 17
        static let sidebarWellIcon: CGFloat = 11
    }

    private static let macOSBodyReference: CGFloat = 13

    /// Scales fixed Anytype targets with the user’s body text preference.
    static var dynamicScale: CGFloat {
        NSFont.preferredFont(forTextStyle: .body).pointSize / macOSBodyReference
    }

    static func scaledPointSize(_ base: CGFloat) -> CGFloat {
        (base * dynamicScale).rounded(toPlaces: 1)
    }

    static func lineSpacing(pointSize: CGFloat, lineHeight: CGFloat) -> CGFloat {
        max(0, lineHeight * dynamicScale - pointSize)
    }

    // MARK: Font availability

    private(set) static var isBundledSerifAvailable: Bool = false

    static let bundledSerifMissingMessage =
        "Source Serif 4 did not load — editor text is using the system serif fallback. Rebuild the app or reinstall bundled fonts."

    @discardableResult
    static func verifyBundledFontsAtLaunch() -> Bool {
        registerBundledSerifFontsIfNeeded()
        isBundledSerifAvailable = NSFont(name: Family.regular, size: 12) != nil
            && NSFont(name: Family.semibold, size: 12) != nil
            && NSFont(name: Family.bold, size: 12) != nil
        return isBundledSerifAvailable
    }

    /// macOS does not auto-register `UIAppFonts` the way iOS does; register from the bundle when needed.
    private static func registerBundledSerifFontsIfNeeded() {
        let bundledNames = [Family.regular, Family.semibold, Family.bold]
        guard bundledNames.contains(where: { NSFont(name: $0, size: 12) == nil }) else { return }

        for url in bundledSerifFontURLs() {
            var error: Unmanaged<CFError>?
            CTFontManagerRegisterFontsForURL(url as CFURL, .process, &error)
        }
    }

    private static func bundledSerifFontURLs() -> [URL] {
        let names = [Family.regular, Family.semibold, Family.bold]
        var urls: [URL] = []
        for name in names {
            if let url = Bundle.main.url(forResource: name, withExtension: "ttf", subdirectory: "Fonts")
                ?? Bundle.main.url(forResource: name, withExtension: "ttf") {
                urls.append(url)
            }
        }
        if urls.count == names.count { return urls }

        if let fontsDir = Bundle.main.url(forResource: "Fonts", withExtension: nil),
           let contents = try? FileManager.default.contentsOfDirectory(
            at: fontsDir,
            includingPropertiesForKeys: nil
           ) {
            return contents.filter { $0.pathExtension.lowercased() == "ttf" && $0.lastPathComponent.hasPrefix("SourceSerif4") }
        }
        return urls
    }

    /// Surfaces the yellow fallback strip only in Debug when registration failed.
    static var showsBundledSerifWarningInUI: Bool {
        #if DEBUG
        return !isBundledSerifAvailable
        #else
        return false
        #endif
    }

    // MARK: Display

    static var documentTitle: Font {
        sized(weight: .bold, pointSize: Scale.documentTitle, relativeTo: .largeTitle)
    }

    static var documentTitleLineSpacing: CGFloat {
        lineSpacing(
            pointSize: scaledPointSize(Scale.documentTitle),
            lineHeight: Scale.documentTitleLineHeight
        )
    }

    static var heading1: Font {
        sized(weight: .semibold, pointSize: Scale.heading1, relativeTo: .title)
    }

    static var heading1LineSpacing: CGFloat {
        lineSpacing(pointSize: scaledPointSize(Scale.heading1), lineHeight: Scale.heading1LineHeight)
    }

    static var heading2: Font {
        sized(weight: .semibold, pointSize: Scale.heading2, relativeTo: .title2)
    }

    static var heading2LineSpacing: CGFloat {
        lineSpacing(pointSize: scaledPointSize(Scale.heading2), lineHeight: Scale.heading2LineHeight)
    }

    static var heading3: Font {
        sized(weight: .medium, pointSize: Scale.heading3, relativeTo: .title3)
    }

    static var heading3LineSpacing: CGFloat {
        lineSpacing(pointSize: scaledPointSize(Scale.heading3), lineHeight: Scale.heading3LineHeight)
    }

    // MARK: UI

    static var sidebarItem: Font {
        sized(weight: .regular, pointSize: Scale.sidebarItem, relativeTo: .callout)
    }

    static var sidebarItemEmphasis: Font {
        sized(weight: .medium, pointSize: Scale.sidebarItem, relativeTo: .callout)
    }

    static var sidebarSection: Font {
        sized(weight: .semibold, pointSize: Scale.caption, relativeTo: .caption)
    }

    static var bodyEmphasis: Font {
        sized(weight: .medium, pointSize: Scale.callout, relativeTo: .callout)
    }

    static var panelTitle: Font {
        sized(weight: .semibold, pointSize: Scale.callout, relativeTo: .headline)
    }

    static var subheadlineEmphasis: Font {
        sized(weight: .semibold, pointSize: Scale.callout, relativeTo: .subheadline)
    }

    static var callout: Font {
        sized(weight: .regular, pointSize: Scale.callout, relativeTo: .callout)
    }

    static var calloutEmphasis: Font {
        sized(weight: .semibold, pointSize: Scale.callout, relativeTo: .callout)
    }

    static var caption: Font {
        sized(weight: .regular, pointSize: Scale.caption, relativeTo: .caption)
    }

    static var captionEmphasis: Font {
        sized(weight: .medium, pointSize: Scale.caption, relativeTo: .caption)
    }

    static var caption2: Font {
        sized(weight: .regular, pointSize: Scale.caption2, relativeTo: .caption2)
    }

    static var footnote: Font {
        sized(weight: .regular, pointSize: Scale.footnote, relativeTo: .footnote)
    }

    static var toolbarLabel: Font {
        sized(weight: .regular, pointSize: Scale.callout, relativeTo: .callout)
    }

    static var pageTypeIcon: Font {
        sized(weight: .medium, pointSize: Scale.pageTypeIcon, relativeTo: .title3)
    }

    static var sidebarWellIcon: Font {
        sized(weight: .semibold, pointSize: Scale.sidebarWellIcon, relativeTo: .caption2)
    }

    static var railSectionLabel: Font {
        sized(weight: .semibold, pointSize: Scale.caption2, relativeTo: .caption2)
    }

    static let railSectionTracking: CGFloat = 1.1

    // MARK: Body

    static var body: Font {
        sized(weight: .regular, pointSize: Scale.body, relativeTo: .body)
    }

    static var bodyLineSpacing: CGFloat {
        lineSpacing(pointSize: scaledPointSize(Scale.body), lineHeight: Scale.bodyLineHeight)
    }

    /// SF Mono — code stays system monospaced.
    static let code = Font.system(.body, design: .monospaced)
    static let codeSmall = Font.system(.callout, design: .monospaced)

    /// SF Symbols — keep system metrics for glyph alignment.
    static let heroSymbol = Font.system(size: 48)

    static var editorNSFont: NSFont {
        let size = scaledPointSize(Scale.body)
        return NSFont(name: Family.regular, size: size)
            ?? NSFont.systemFont(ofSize: size)
    }

    static var editorParagraphStyle: NSParagraphStyle {
        let style = NSMutableParagraphStyle()
        let size = scaledPointSize(Scale.body)
        style.minimumLineHeight = Scale.bodyLineHeight * dynamicScale
        style.maximumLineHeight = style.minimumLineHeight
        style.lineSpacing = max(0, style.minimumLineHeight - size)
        style.paragraphSpacing = 6
        return style
    }

    static var editorTypingAttributes: [NSAttributedString.Key: Any] {
        [
            .font: editorNSFont,
            .paragraphStyle: editorParagraphStyle,
            .foregroundColor: NSColor(ThemeManager.shared.palette.textPrimary)
        ]
    }

    static func sized(weight: Weight, pointSize: CGFloat, relativeTo style: Font.TextStyle) -> Font {
        let size = scaledPointSize(pointSize)
        let postScript = postScriptName(for: weight)
        if NSFont(name: postScript, size: size) != nil {
            return Font.custom(postScript, size: size, relativeTo: style)
        }
        return Font.system(style).weight(swiftUIWeight(for: weight))
    }

    private static func postScriptName(for weight: Weight) -> String {
        switch weight {
        case .regular: return Family.regular
        case .medium, .semibold: return Family.semibold
        case .bold: return Family.bold
        }
    }

    private static func swiftUIWeight(for weight: Weight) -> Font.Weight {
        switch weight {
        case .regular: return .regular
        case .medium: return .medium
        case .semibold: return .semibold
        case .bold: return .bold
        }
    }
}

private extension CGFloat {
    func rounded(toPlaces places: Int) -> CGFloat {
        let factor = pow(10, CGFloat(places))
        return (self * factor).rounded() / factor
    }
}
