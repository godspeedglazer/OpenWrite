import AppKit
import Foundation

/// Inline markdown subset for block `text` — persists in NDL as plain line content.
/// Supports `**bold**`, `*italic*`, `~~strike~~`, `<u>underline</u>`.
enum InlineMarkdown {
    static let underlineOpen = "<u>"
    static let underlineClose = "</u>"

    enum FontFamily: String {
        case serif
        case sans

        init?(attribute: String?) {
            guard let attribute, let parsed = FontFamily(rawValue: attribute) else { return nil }
            self = parsed
        }
    }

    static func baseNSFont(family: FontFamily?, pointSize: CGFloat?) -> NSFont {
        let size = pointSize ?? OWTypography.Scale.body
        switch family ?? .serif {
        case .serif:
            return NSFont(name: OWTypography.Family.regular, size: size)
                ?? NSFont.systemFont(ofSize: size)
        case .sans:
            return NSFont.systemFont(ofSize: size)
        }
    }

    static func attributedString(
        from markdown: String,
        family: FontFamily?,
        pointSize: CGFloat?,
        textColor: NSColor
    ) -> NSAttributedString {
        let base = baseNSFont(family: family, pointSize: pointSize)
        let result = NSMutableAttributedString()
        var index = markdown.startIndex

        while index < markdown.endIndex {
            if let match = matchPrefix(at: index, in: markdown) {
                if index < match.openStart {
                    let plain = String(markdown[index..<match.openStart])
                    result.append(plainSegment(plain, base: base, color: textColor))
                }
                let inner = String(markdown[match.contentStart..<match.contentEnd])
                result.append(styledSegment(inner, style: match.style, base: base, color: textColor))
                index = match.closeEnd
                continue
            }

            let nextSpecial = markdown[index...].firstIndex { ch in
                ch == "*" || ch == "~" || ch == "<"
            } ?? markdown.endIndex
            let plain = String(markdown[index..<nextSpecial])
            result.append(plainSegment(plain, base: base, color: textColor))
            index = nextSpecial
        }

        return result
    }

    static func markdown(from attributed: NSAttributedString) -> String {
        guard attributed.length > 0 else { return "" }
        var output = ""
        attributed.enumerateAttributes(in: NSRange(location: 0, length: attributed.length)) { attrs, range, _ in
            let fragment = (attributed.string as NSString).substring(with: range)
            guard !fragment.isEmpty else { return }
            var wrapped = fragment
            if attrs[.strikethroughStyle] != nil {
                wrapped = "~~\(wrapped)~~"
            }
            if attrs[.underlineStyle] != nil {
                wrapped = "\(underlineOpen)\(wrapped)\(underlineClose)"
            }
            let fragmentBase = (attrs[.font] as? NSFont) ?? baseNSFont(family: nil, pointSize: nil)
            if isItalic(attrs, baseFont: fragmentBase) {
                wrapped = "*\(wrapped)*"
            }
            if isBold(attrs, baseFont: fragmentBase) {
                wrapped = "**\(wrapped)**"
            }
            output += wrapped
        }
        return output
    }

    static func selectionOrAll(in textView: NSTextView) -> NSRange {
        let range = textView.selectedRange()
        if range.length > 0 { return range }
        let length = (textView.string as NSString).length
        return length > 0 ? NSRange(location: 0, length: length) : range
    }

    /// Range used to reflect toolbar toggle state at the caret or selection.
    static func inspectionRange(in textView: NSTextView) -> NSRange {
        let selected = textView.selectedRange()
        if selected.length > 0 { return selected }
        let length = (textView.string as NSString).length
        guard length > 0 else { return NSRange(location: 0, length: 0) }
        let index = min(max(selected.location, 0), length - 1)
        return NSRange(location: index, length: 1)
    }

    struct FormatState: Equatable {
        var isBold = false
        var isItalic = false
        var isUnderline = false
        var isStrikethrough = false
    }

    static func formatState(in textView: NSTextView, baseFont: NSFont) -> FormatState {
        guard let storage = textView.textStorage else { return FormatState() }
        let range = inspectionRange(in: textView)
        guard range.length > 0 else { return FormatState() }
        var state = FormatState()
        storage.enumerateAttributes(in: range) { attrs, _, _ in
            if isBold(attrs, baseFont: baseFont) { state.isBold = true }
            if isItalic(attrs, baseFont: baseFont) { state.isItalic = true }
            if attrs[.underlineStyle] != nil { state.isUnderline = true }
            if attrs[.strikethroughStyle] != nil { state.isStrikethrough = true }
        }
        return state
    }

    static func toggleBold(in textView: NSTextView, baseFont: NSFont) {
        toggleFontTrait(in: textView, trait: .boldFontMask, baseFont: baseFont)
    }

    static func toggleItalic(in textView: NSTextView, baseFont: NSFont) {
        toggleFontTrait(in: textView, trait: .italicFontMask, baseFont: baseFont)
    }

    static func toggleUnderline(in textView: NSTextView) {
        toggleAttribute(in: textView, key: .underlineStyle, onValue: NSUnderlineStyle.single.rawValue)
    }

    static func toggleStrikethrough(in textView: NSTextView) {
        toggleAttribute(in: textView, key: .strikethroughStyle, onValue: NSUnderlineStyle.single.rawValue)
    }

    private static func toggleFontTrait(in textView: NSTextView, trait: NSFontTraitMask, baseFont: NSFont) {
        guard let storage = textView.textStorage else { return }
        let range = selectionOrAll(in: textView)
        guard range.length > 0 else { return }
        storage.enumerateAttribute(.font, in: range) { value, subrange, _ in
            let current = (value as? NSFont) ?? baseFont
            let hasTrait = current.fontDescriptor.symbolicTraits.contains(trait == .boldFontMask ? .bold : .italic)
            let updated = hasTrait
                ? NSFontManager.shared.convert(current, toNotHaveTrait: trait)
                : NSFontManager.shared.convert(current, toHaveTrait: trait)
            storage.addAttribute(.font, value: updated, range: subrange)
        }
        textView.setSelectedRange(range)
    }

    private static func toggleAttribute(in textView: NSTextView, key: NSAttributedString.Key, onValue: Int) {
        guard let storage = textView.textStorage else { return }
        let range = selectionOrAll(in: textView)
        guard range.length > 0 else { return }
        let active = storage.attribute(key, at: range.location, effectiveRange: nil) != nil
        if active {
            storage.removeAttribute(key, range: range)
        } else {
            storage.addAttribute(key, value: onValue, range: range)
        }
        textView.setSelectedRange(range)
    }

    // MARK: - Private

    private enum InlineStyle {
        case bold, italic, strike, underline
    }

    private struct MarkerMatch {
        let openStart: String.Index
        let contentStart: String.Index
        let contentEnd: String.Index
        let closeEnd: String.Index
        let style: InlineStyle
    }

    private static func matchPrefix(at index: String.Index, in markdown: String) -> MarkerMatch? {
        let tail = markdown[index...]
        if tail.hasPrefix("**"), let close = findUnescaped("**", in: markdown, from: markdown.index(index, offsetBy: 2)) {
            return MarkerMatch(
                openStart: index,
                contentStart: markdown.index(index, offsetBy: 2),
                contentEnd: close,
                closeEnd: markdown.index(close, offsetBy: 2),
                style: .bold
            )
        }
        if tail.hasPrefix("~~"), let close = findUnescaped("~~", in: markdown, from: markdown.index(index, offsetBy: 2)) {
            return MarkerMatch(
                openStart: index,
                contentStart: markdown.index(index, offsetBy: 2),
                contentEnd: close,
                closeEnd: markdown.index(close, offsetBy: 2),
                style: .strike
            )
        }
        if tail.hasPrefix(underlineOpen), let close = markdown[markdown.index(index, offsetBy: underlineOpen.count)...].range(of: underlineClose) {
            return MarkerMatch(
                openStart: index,
                contentStart: markdown.index(index, offsetBy: underlineOpen.count),
                contentEnd: close.lowerBound,
                closeEnd: close.upperBound,
                style: .underline
            )
        }
        if tail.hasPrefix("*"), !tail.hasPrefix("**"),
           let close = findUnescaped("*", in: markdown, from: markdown.index(index, offsetBy: 1)) {
            return MarkerMatch(
                openStart: index,
                contentStart: markdown.index(index, offsetBy: 1),
                contentEnd: close,
                closeEnd: markdown.index(close, offsetBy: 1),
                style: .italic
            )
        }
        return nil
    }

    private static func findUnescaped(_ marker: String, in markdown: String, from start: String.Index) -> String.Index? {
        var search = start
        while search < markdown.endIndex, let range = markdown[search...].range(of: marker) {
            if range.lowerBound == markdown.startIndex || markdown[markdown.index(before: range.lowerBound)] != "\\" {
                return range.lowerBound
            }
            search = range.upperBound
        }
        return nil
    }

    private static func plainSegment(_ text: String, base: NSFont, color: NSColor) -> NSAttributedString {
        NSAttributedString(string: text, attributes: baseAttributes(base: base, color: color))
    }

    private static func styledSegment(_ text: String, style: InlineStyle, base: NSFont, color: NSColor) -> NSAttributedString {
        var attrs = baseAttributes(base: base, color: color)
        switch style {
        case .bold:
            attrs[.font] = boldFont(from: base)
        case .italic:
            attrs[.font] = italicFont(from: base)
        case .strike:
            attrs[.strikethroughStyle] = NSUnderlineStyle.single.rawValue
        case .underline:
            attrs[.underlineStyle] = NSUnderlineStyle.single.rawValue
        }
        return NSAttributedString(string: text, attributes: attrs)
    }

    private static func baseAttributes(base: NSFont, color: NSColor) -> [NSAttributedString.Key: Any] {
        [.font: base, .foregroundColor: color]
    }

    private static func boldFont(from base: NSFont) -> NSFont {
        let converted = NSFontManager.shared.convert(base, toHaveTrait: .boldFontMask)
        return converted.pointSize > 0 ? converted : NSFont.boldSystemFont(ofSize: base.pointSize)
    }

    private static func italicFont(from base: NSFont) -> NSFont {
        let converted = NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
        return converted.pointSize > 0 ? converted : NSFontManager.shared.convert(base, toHaveTrait: .italicFontMask)
    }

    private static func isBold(_ attrs: [NSAttributedString.Key: Any], baseFont: NSFont) -> Bool {
        let font = (attrs[.font] as? NSFont) ?? baseFont
        return font.fontDescriptor.symbolicTraits.contains(.bold)
    }

    private static func isItalic(_ attrs: [NSAttributedString.Key: Any], baseFont: NSFont) -> Bool {
        let font = (attrs[.font] as? NSFont) ?? baseFont
        return font.fontDescriptor.symbolicTraits.contains(.italic)
    }
}
