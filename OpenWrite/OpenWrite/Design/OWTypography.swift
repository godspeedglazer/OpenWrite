import AppKit
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

    // MARK: Display

    static let documentTitle = custom(role: .display, weight: .bold, relativeTo: .largeTitle)
    static let heading1 = custom(role: .display, weight: .semibold, relativeTo: .title)
    static let heading2 = custom(role: .display, weight: .semibold, relativeTo: .title2)
    static let heading3 = custom(role: .display, weight: .medium, relativeTo: .title3)

    // MARK: UI

    static let sidebarItem = custom(role: .ui, weight: .regular, relativeTo: .body)
    static let sidebarItemEmphasis = custom(role: .ui, weight: .medium, relativeTo: .body)
    static let sidebarSection = custom(role: .ui, weight: .semibold, relativeTo: .caption)
    static let bodyEmphasis = custom(role: .ui, weight: .medium, relativeTo: .body)
    static let panelTitle = custom(role: .ui, weight: .semibold, relativeTo: .headline)
    static let subheadlineEmphasis = custom(role: .ui, weight: .semibold, relativeTo: .subheadline)
    static let callout = custom(role: .ui, weight: .regular, relativeTo: .callout)
    static let calloutEmphasis = custom(role: .ui, weight: .semibold, relativeTo: .callout)
    static let caption = custom(role: .ui, weight: .regular, relativeTo: .caption)
    static let captionEmphasis = custom(role: .ui, weight: .medium, relativeTo: .caption)
    static let caption2 = custom(role: .ui, weight: .regular, relativeTo: .caption2)
    static let footnote = custom(role: .ui, weight: .regular, relativeTo: .footnote)
    static let toolbarLabel = custom(role: .ui, weight: .regular, relativeTo: .callout)
    static let pageTypeIcon = custom(role: .ui, weight: .medium, relativeTo: .title3)
    static let sidebarWellIcon = custom(role: .ui, weight: .semibold, relativeTo: .caption2)
    static let railSectionLabel = custom(role: .ui, weight: .semibold, relativeTo: .caption2)
    static let railSectionTracking: CGFloat = 1.1

    // MARK: Body

    static let body = custom(role: .body, weight: .regular, relativeTo: .body)

    /// SF Mono — code stays system monospaced.
    static let code = Font.system(.body, design: .monospaced)
    static let codeSmall = Font.system(.callout, design: .monospaced)

    /// SF Symbols — keep system metrics for glyph alignment.
    static let heroSymbol = Font.system(size: 48)

    static var editorNSFont: NSFont {
        let size = NSFont.preferredFont(forTextStyle: .body).pointSize
        return NSFont(name: Family.regular, size: size) ?? .systemFont(ofSize: size)
    }

    static func custom(role: Role, weight: Weight, relativeTo style: Font.TextStyle) -> Font {
        switch role {
        case .display, .ui, .body:
            break
        }
        let postScript = postScriptName(for: weight)
        let size = NSFont.preferredFont(forTextStyle: nsTextStyle(for: style)).pointSize
        return Font.custom(postScript, size: size, relativeTo: style)
    }

    private static func postScriptName(for weight: Weight) -> String {
        switch weight {
        case .regular: return Family.regular
        case .medium, .semibold: return Family.semibold
        case .bold: return Family.bold
        }
    }

    private static func nsTextStyle(for style: Font.TextStyle) -> NSFont.TextStyle {
        switch style {
        case .largeTitle: return .largeTitle
        case .title: return .title1
        case .title2: return .title2
        case .title3: return .title3
        case .headline: return .headline
        case .subheadline: return .subheadline
        case .body: return .body
        case .callout: return .callout
        case .caption: return .caption1
        case .caption2: return .caption2
        case .footnote: return .footnote
        @unknown default: return .body
        }
    }
}
