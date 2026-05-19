import Foundation

// MARK: - Actions

/// Structured editor / workbench commands parsed from model output (`ow` script).
enum OWAction: Equatable, Sendable {
    case insertBlock(kind: NoteBlock.Kind, text: String, checked: Bool?)
    case insertChecklist(items: [String])
    case refreshGraph
}

struct OWActionScriptParseResult: Sendable {
    var actions: [OWAction]
    /// Prose with ```ow``` fences removed — safe to apply as a text refinement.
    var proseWithoutScripts: String
}

// MARK: - Parser

enum OWActionScript {
    static let fenceLanguage = "ow"

    /// Extracts actions from fenced ```ow blocks and `ow …` single lines.
    static func parse(in text: String) -> OWActionScriptParseResult {
        var actions: [OWAction] = []
        var prose = text

        prose = stripFencedScripts(from: prose, into: &actions)
        parseLineCommands(in: prose, into: &actions, prose: &prose)

        let trimmedProse = prose.trimmingCharacters(in: .whitespacesAndNewlines)
        return OWActionScriptParseResult(actions: actions, proseWithoutScripts: trimmedProse)
    }

    static func systemPromptAppendix() -> String {
        """
        When you need to change the note structure (not only rewrite prose), append a fenced OpenWrite script:

        ```ow
        insert paragraph "Optional caption"
        insert todo unchecked "Task label"
        insert h2 "Section title"
        insert checklist
          First item
          Second item
        insert divider
        graph refresh
        ```

        Use `insert` kinds: paragraph, bullet, todo, h1, h2, h3, quote, callout, code, divider, wikilink.
        For todos use `checked` or `unchecked`. Checklist items are indented lines after `insert checklist`.
        `graph refresh` asks the app to reload the link graph view.
        """
    }

    // MARK: - Fence stripping

    private static func stripFencedScripts(from text: String, into actions: inout [OWAction]) -> String {
        var output = ""
        var index = text.startIndex

        while index < text.endIndex {
            guard let open = text.range(of: "```\(fenceLanguage)", range: index..<text.endIndex) else {
                output += text[index...]
                break
            }
            output += text[index..<open.lowerBound]
            let bodyStart = open.upperBound
            guard let close = text.range(of: "```", range: bodyStart..<text.endIndex) else {
                output += text[index...]
                break
            }
            let body = String(text[bodyStart..<close.lowerBound])
            parseScriptBody(body, into: &actions)
            index = close.upperBound
        }

        return output
    }

    private static func parseLineCommands(
        in text: String,
        into actions: inout [OWAction],
        prose: inout String
    ) {
        var keptLines: [String] = []
        for line in text.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.lowercased().hasPrefix("ow ") || trimmed.lowercased().hasPrefix("ow.") {
                let command = trimmed
                    .replacingOccurrences(of: "ow.", with: "", options: .caseInsensitive)
                    .replacingOccurrences(of: "ow ", with: "", options: .caseInsensitive)
                if let action = parseCommandLine(command) {
                    actions.append(action)
                    continue
                }
            }
            keptLines.append(line)
        }
        prose = keptLines.joined(separator: "\n")
    }

    private static func parseScriptBody(_ body: String, into actions: inout [OWAction]) {
        let lines = body.components(separatedBy: .newlines)
        var index = 0
        while index < lines.count {
            let line = lines[index].trimmingCharacters(in: .whitespaces)
            index += 1
            guard !line.isEmpty, !line.hasPrefix("#") else { continue }

            if line.lowercased() == "graph refresh" || line.lowercased() == "refresh graph" {
                actions.append(.refreshGraph)
                continue
            }

            if line.lowercased().hasPrefix("insert checklist") {
                var items: [String] = []
                while index < lines.count {
                    let next = lines[index]
                    let item = checklistItemLine(next)
                    guard !item.isEmpty else { break }
                    items.append(item)
                    index += 1
                }
                if items.isEmpty { items = [""] }
                actions.append(.insertChecklist(items: items))
                continue
            }

            if line.lowercased().hasPrefix("insert ") {
                if let action = parseInsertLine(line) {
                    actions.append(action)
                }
                continue
            }

            if let action = parseCommandLine(line) {
                actions.append(action)
            }
        }
    }

    private static func checklistItemLine(_ line: String) -> String {
        let trimmed = line.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("- ") { return String(trimmed.dropFirst(2)) }
        if trimmed.hasPrefix("• ") { return String(trimmed.dropFirst(2)) }
        if trimmed.hasPrefix("* ") { return String(trimmed.dropFirst(2)) }
        if trimmed.isEmpty { return "" }
        return ""
    }

    private static func parseInsertLine(_ line: String) -> OWAction? {
        let remainder = line.dropFirst("insert ".count).trimmingCharacters(in: .whitespaces)
        return parseInsertTail(String(remainder))
    }

    private static func parseCommandLine(_ line: String) -> OWAction? {
        let lower = line.lowercased()
        if lower == "graph refresh" || lower == "refresh graph" {
            return .refreshGraph
        }
        if lower.hasPrefix("insert ") {
            return parseInsertLine(line)
        }
        return nil
    }

    private static func parseInsertTail(_ tail: String) -> OWAction? {
        var working = tail
        var checked: Bool?
        for flag in ["unchecked", "checked"] {
            if working.lowercased().hasPrefix(flag) {
                checked = flag == "checked"
                working = String(working.dropFirst(flag.count)).trimmingCharacters(in: .whitespaces)
                break
            }
        }

        guard let firstToken = working.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true).first else {
            return nil
        }
        let kindToken = String(firstToken).lowercased()
        let textTail = working.dropFirst(firstToken.count).trimmingCharacters(in: .whitespaces)
        let text = parseQuoted(Substring(textTail)) ?? textTail.trimmingCharacters(in: CharacterSet(charactersIn: "\""))

        guard let kind = mapKind(kindToken) else { return nil }
        if kind == .todo {
            return .insertBlock(kind: .todo, text: text, checked: checked ?? false)
        }
        return .insertBlock(kind: kind, text: text, checked: nil)
    }

    private static func parseQuoted(_ raw: Substring) -> String? {
        let s = raw.trimmingCharacters(in: .whitespaces)
        guard s.count >= 2, s.first == "\"", s.last == "\"" else { return nil }
        return String(s.dropFirst().dropLast())
    }

    private static func mapKind(_ token: String) -> NoteBlock.Kind? {
        switch token {
        case "p", "para", "paragraph": return .paragraph
        case "bullet", "list", "ul": return .bullet
        case "todo", "task", "checkbox": return .todo
        case "h1", "heading1": return .heading1
        case "h2", "heading2": return .heading2
        case "h3", "heading3": return .heading3
        case "quote", "blockquote": return .quote
        case "callout": return .callout
        case "code": return .code
        case "divider", "hr": return .divider
        case "wikilink", "link": return .wikilink
        default: return nil
        }
    }
}

// MARK: - Executor

enum OWActionExecutor {
    struct ApplyResult {
        var blocks: [NoteBlock]
        var graphRefreshRequested: Bool
    }

    @MainActor
    static func apply(
        _ actions: [OWAction],
        to blocks: [NoteBlock],
        insertAfter focusedBlockID: UUID?
    ) -> ApplyResult {
        var working = blocks
        var graphRefresh = false
        var anchorID = focusedBlockID

        for action in actions {
            switch action {
            case .refreshGraph:
                graphRefresh = true
            case .insertChecklist(let items):
                for item in items {
                    let block = NoteBlock.todoBlock(text: item, checked: false)
                    insert(block, into: &working, after: anchorID)
                    anchorID = block.id
                }
            case .insertBlock(let kind, let text, let checked):
                let block = makeBlock(kind: kind, text: text, checked: checked)
                insert(block, into: &working, after: anchorID)
                anchorID = block.id
            }
        }

        return ApplyResult(blocks: working, graphRefreshRequested: graphRefresh)
    }

    private static func makeBlock(kind: NoteBlock.Kind, text: String, checked: Bool?) -> NoteBlock {
        switch kind {
        case .todo:
            return NoteBlock.todoBlock(text: text, checked: checked ?? false)
        case .callout:
            return NoteBlock(kind: .callout, text: text, attributes: ["callout": "note"])
        default:
            return NoteBlock(kind: kind, text: text)
        }
    }

    private static func insert(
        _ block: NoteBlock,
        into blocks: inout [NoteBlock],
        after focusID: UUID?
    ) {
        if let focusID, let index = blocks.firstIndex(where: { $0.id == focusID }) {
            blocks.insert(block, at: index + 1)
        } else {
            blocks.append(block)
        }
    }
}
