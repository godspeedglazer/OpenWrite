import Foundation

/// Filename-only labels for RAG source pills — never absolute or Application Support paths.
enum SourceDisplayName {
    static func filename(from raw: String) -> String {
        var value = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !value.isEmpty else { return "" }

        if value.hasPrefix("~") {
            value = (value as NSString).expandingTildeInPath
        }

        if looksLikeFilesystemPath(value) {
            let leaf = (value as NSString).lastPathComponent
            if !leaf.isEmpty, leaf != "/", leaf != "." { return leaf }
        }

        if value.contains("/") || value.contains("\\") {
            let leaf = (value as NSString).lastPathComponent
            if !leaf.isEmpty { return leaf }
        }

        return value
    }

    static func looksLikeFilesystemPath(_ value: String) -> Bool {
        if value.hasPrefix("/") || value.hasPrefix("~") { return true }
        if value.contains("/Users/") || value.contains("\\Users\\") { return true }
        if value.localizedCaseInsensitiveContains("library/application support") { return true }
        if value.localizedCaseInsensitiveContains("application support"), value.contains("/") {
            return true
        }
        if value.contains("/") || value.contains("\\") {
            let parts = value.split { $0 == "/" || $0 == "\\" }
            if parts.count >= 3 { return true }
        }
        let pattern = #"^[A-Za-z]:\\"#
        if value.range(of: pattern, options: .regularExpression) != nil { return true }
        return false
    }
}
