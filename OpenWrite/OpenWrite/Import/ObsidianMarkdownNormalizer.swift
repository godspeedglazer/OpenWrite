import Foundation

/// Normalizes Obsidian-flavored markdown before NDL parse.
enum ObsidianMarkdownNormalizer {
    static func normalize(_ markdown: String) -> String {
        var text = stripYAMLFrontmatter(markdown)
        text = normalizeWikilinks(text)
        text = text.replacingOccurrences(of: "\r\n", with: "\n")
        return text
    }

    private static func stripYAMLFrontmatter(_ source: String) -> String {
        let trimmed = source.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.hasPrefix("---") else { return source }
        var index = trimmed.index(trimmed.startIndex, offsetBy: 3)
        guard let close = trimmed[index...].range(of: "\n---") else { return source }
        let bodyStart = close.upperBound
        return String(trimmed[bodyStart...]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// `[[Page|Alias]]` → `[[Page]]` for OpenWrite wikilinks.
    private static func normalizeWikilinks(_ text: String) -> String {
        guard text.contains("[[") else { return text }
        var output = ""
        var index = text.startIndex
        while index < text.endIndex {
            guard let open = text.range(of: "[[", range: index..<text.endIndex) else {
                output += text[index...]
                break
            }
            output += text[index..<open.lowerBound]
            guard let close = text.range(of: "]]", range: open.upperBound..<text.endIndex) else {
                output += text[index...]
                break
            }
            let inner = String(text[open.upperBound..<close.lowerBound])
            let target = inner.split(separator: "|", maxSplits: 1).first.map(String.init) ?? inner
            output += "[[\(target.trimmingCharacters(in: .whitespaces))]]"
            index = close.upperBound
        }
        return output
    }
}
