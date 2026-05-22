import Foundation

struct WritingTestCase {
    let id: String
    let name: String
    let run: () throws -> Void
}

enum WritingTestSuite {
    static func defaultSuite() -> [WritingTestCase] {
        [
            WritingTestCase(id: "W-NDL-01", name: "NDL paragraph round-trip", run: testNDLParagraphRoundTrip),
            WritingTestCase(id: "W-NDL-02", name: "NDL headings round-trip", run: testNDLHeadingsRoundTrip),
            WritingTestCase(id: "W-NDL-03", name: "NDL todo checked", run: testNDLTodoChecked),
            WritingTestCase(id: "W-NDL-04", name: "NDL code fence", run: testNDLCodeFence),
            WritingTestCase(id: "W-NDL-05", name: "NDL wikilink", run: testNDLWikilink),
            WritingTestCase(id: "W-NDL-06", name: "NDL callout", run: testNDLCallout),
            WritingTestCase(id: "W-NDL-07", name: "NDL property line", run: testNDLProperty),
            WritingTestCase(id: "W-NDL-08", name: "NDL multi-block document", run: testNDLDocumentSample),
            WritingTestCase(id: "W-REF-01", name: "Refine apply exact match", run: testRefineExactMatch),
            WritingTestCase(id: "W-REF-02", name: "Refine apply NSRange", run: testRefineNSRange),
            WritingTestCase(id: "W-REF-03", name: "Refine apply duplicate uses range", run: testRefineDuplicateUsesRange),
            WritingTestCase(id: "W-REF-04", name: "Refine apply no match replaces block", run: testRefineNoMatchWholeBlock),
            WritingTestCase(id: "W-REF-05", name: "Refine apply empty rejected", run: testRefineEmptyRejected),
            WritingTestCase(id: "W-PRM-01", name: "Refine prompts contain SELECTION", run: testRefinePromptsContainSelection),
            WritingTestCase(id: "W-PRM-02", name: "Refine prompts include ow appendix", run: testRefinePromptsOwAppendix),
            WritingTestCase(id: "W-ACT-01", name: "OW script parse todo", run: testOWScriptParseTodo),
            WritingTestCase(id: "W-CHK-01", name: "Chunker title-lead chunk", run: testChunkerTitleLead),
            WritingTestCase(id: "W-CHK-02", name: "Chunker section breadcrumb", run: testChunkerSectionBreadcrumb),
            WritingTestCase(id: "W-CHK-03", name: "Chunker omits code from embed", run: testChunkerOmitsCode),
            WritingTestCase(id: "W-KEY-01", name: "Keyboard Enter split", run: testKeyboardSplit),
            WritingTestCase(id: "W-KEY-02", name: "Keyboard Backspace merge", run: testKeyboardMerge),
            WritingTestCase(id: "W-PST-01", name: "Rich paste HTML paragraphs", run: testRichPasteHTML),
        ]
    }

    static func runAll(filter: String?) -> (passed: Int, failed: Int, failures: [(id: String, error: String)]) {
        var passed = 0
        var failed = 0
        var failures: [(String, String)] = []
        let suite = defaultSuite().filter { test in
            guard let filter, !filter.isEmpty else { return true }
            return test.id.localizedCaseInsensitiveContains(filter)
                || test.name.localizedCaseInsensitiveContains(filter)
        }
        for test in suite {
            do {
                try test.run()
                passed += 1
            } catch {
                failed += 1
                failures.append((test.id, error.localizedDescription))
            }
        }
        return (passed, failed, failures)
    }

    // MARK: - NDL

    private static func testNDLParagraphRoundTrip() throws {
        let source = "Plain paragraph line."
        let blocks = NDLParser.parse(source)
        let out = NDLSerializer.serialize(blocks: blocks)
        let again = NDLParser.parse(out)
        try assertEqual(blocks.map(\.kind), again.map(\.kind))
        try assertEqual(blocks.map(\.text), again.map(\.text))
    }

    private static func testNDLHeadingsRoundTrip() throws {
        let source = """
        # One
        ## Two
        ### Three
        """
        let blocks = NDLParser.parse(source)
        try assert(blocks.count == 3, "expected 3 blocks")
        try assert(blocks[0].kind == .heading1 && blocks[0].text == "One")
        try assert(blocks[1].kind == .heading2)
        try assert(blocks[2].kind == .heading3)
    }

    private static func testNDLTodoChecked() throws {
        let block = NoteBlock.todoBlock(text: "Ship tests", checked: true)
        let line = NDLSerializer.serializeBlock(block)
        try assert(line.contains("[x]"), "checked todo")
        let parsed = NDLParser.parse(line)
        try assert(parsed.first?.isChecked == true)
    }

    private static func testNDLCodeFence() throws {
        let source = """
        ```swift
        let x = 1
        ```
        """
        let blocks = NDLParser.parse(source)
        try assert(blocks.count == 1 && blocks[0].kind == .code)
        try assert(blocks[0].attributes["language"] == "swift")
        try assert(blocks[0].text.contains("let x"))
    }

    private static func testNDLWikilink() throws {
        let blocks = NDLParser.parse("[[Daily Brief]]")
        try assert(blocks.first?.kind == .wikilink)
        try assert(blocks.first?.text == "Daily Brief")
    }

    private static func testNDLCallout() throws {
        let block = NoteBlock(kind: .callout, text: "Hint", attributes: ["callout": "tip"])
        let line = NDLSerializer.serializeBlock(block)
        try assert(line.contains("[!tip]"))
    }

    private static func testNDLProperty() throws {
        let block = NoteBlock.propertyBlock(key: .title, value: "Morning draft")
        let line = NDLSerializer.serializeBlock(block)
        try assert(line.hasPrefix("@"))
        let parsed = NDLParser.parse(line)
        try assert(parsed.first?.kind == .property)
    }

    private static func testNDLDocumentSample() throws {
        let source = """
        # Draft

        Opening **bold** thought.

        - [ ] Finish section
        """
        let blocks = NDLParser.parse(source)
        try assert(blocks.count >= 3)
        let serialized = NDLSerializer.serialize(blocks: blocks)
        try assert(serialized.contains("# Draft"))
        try assert(serialized.contains("- [ ]"))
    }

    // MARK: - Refine apply

    private static func testRefineExactMatch() throws {
        let id = UUID()
        var blocks = [NoteBlock(id: id, kind: .paragraph, text: "The cat sat on the mat.")]
        let snap = InlineSelectionSnapshot(
            documentID: UUID(),
            blockID: id,
            selectedText: "cat sat",
            selectedRange: NSRange(location: NSNotFound, length: 0)
        )
        try assert(BlockRefinement.apply("feline rested", snapshot: snap, blocks: &blocks))
        try assert(blocks[0].text == "The feline rested on the mat.")
    }

    private static func testRefineNSRange() throws {
        let id = UUID()
        var blocks = [NoteBlock(id: id, kind: .paragraph, text: "alpha beta gamma")]
        let snap = InlineSelectionSnapshot(
            documentID: UUID(),
            blockID: id,
            selectedText: "beta",
            selectedRange: NSRange(location: 6, length: 4)
        )
        try assert(BlockRefinement.apply("BETA", snapshot: snap, blocks: &blocks))
        try assert(blocks[0].text == "alpha BETA gamma")
    }

    private static func testRefineDuplicateUsesRange() throws {
        let id = UUID()
        var blocks = [NoteBlock(id: id, kind: .paragraph, text: "the the end")]
        let snap = InlineSelectionSnapshot(
            documentID: UUID(),
            blockID: id,
            selectedText: "the",
            selectedRange: NSRange(location: 4, length: 3)
        )
        try assert(BlockRefinement.apply("a", snapshot: snap, blocks: &blocks))
        try assert(blocks[0].text == "the a end", "second 'the' should change")
    }

    private static func testRefineNoMatchWholeBlock() throws {
        let id = UUID()
        var blocks = [NoteBlock(id: id, kind: .paragraph, text: "Original body.")]
        let snap = InlineSelectionSnapshot(
            documentID: UUID(),
            blockID: id,
            selectedText: "missing",
            selectedRange: NSRange(location: NSNotFound, length: 0)
        )
        try assert(BlockRefinement.apply("Replaced entirely.", snapshot: snap, blocks: &blocks))
        try assert(blocks[0].text == "Replaced entirely.")
    }

    private static func testRefineEmptyRejected() throws {
        let id = UUID()
        var blocks = [NoteBlock(id: id, kind: .paragraph, text: "Keep.")]
        let snap = InlineSelectionSnapshot(
            documentID: UUID(),
            blockID: id,
            selectedText: "Keep",
            selectedRange: NSRange(location: 0, length: 4)
        )
        try assert(!BlockRefinement.apply("   \n", snapshot: snap, blocks: &blocks))
        try assert(blocks[0].text == "Keep.")
    }

    // MARK: - Prompts & actions

    private static func testRefinePromptsContainSelection() throws {
        for preset in RefinePromptPreset.allCases {
            let q = RefinePrompts.buildQuery(selection: "Sample line.", preset: preset, noteExcerpt: nil)
            try assert(q.contains("SELECTION"), preset.rawValue)
            try assert(q.contains("Sample line."), preset.rawValue)
        }
    }

    private static func testRefinePromptsOwAppendix() throws {
        let q = RefinePrompts.buildQuery(selection: "x", preset: .improve, noteExcerpt: nil)
        try assert(q.contains("```ow"))
    }

    private static func testOWScriptParseTodo() throws {
        let parsed = OWActionScript.parse(in: """
        ```ow
        insert todo unchecked "Ship the slow test suite"
        ```
        """)
        try assert(parsed.actions.count == 1)
        if case .insertBlock(let kind, let text, let checked) = parsed.actions[0] {
            try assert(kind == .todo)
            try assert(text.contains("slow test"))
            try assert(checked == false)
        } else {
            throw WritingTestError.assertion("expected insertBlock todo")
        }
    }

    // MARK: - Chunker

    private static func testChunkerTitleLead() throws {
        let docID = UUID()
        let blocks = [
            NoteBlock(kind: .heading1, text: "Essay"),
            NoteBlock(kind: .paragraph, text: "First paragraph of the essay.")
        ]
        let chunks = TextChunker.chunks(
            documentID: docID,
            title: "Essay",
            blocks: blocks,
            sourceFilename: "Essay.md"
        )
        try assert(chunks.contains(where: \.isTitleLeadChunk))
    }

    private static func testChunkerSectionBreadcrumb() throws {
        let docID = UUID()
        let blocks = [
            NoteBlock(kind: .heading1, text: "Part"),
            NoteBlock(kind: .heading2, text: "Section"),
            NoteBlock(kind: .paragraph, text: "Body under section.")
        ]
        let chunks = TextChunker.chunks(documentID: docID, title: "Doc", blocks: blocks)
        try assert(chunks.contains { ($0.headingPath ?? "").contains("Part") })
        try assert(chunks.contains { $0.text.contains("Section:") || $0.text.contains("Part >") })
    }

    private static func testKeyboardSplit() throws {
        let id = UUID()
        var blocks = [NoteBlock(id: id, kind: .paragraph, text: "Hello world")]
        let result = BlockKeyboardEditing.split(blocks: &blocks, blockID: id, cursorOffset: 5)
        try assert(result != nil)
        try assert(blocks.count == 2)
        try assert(blocks[0].text == "Hello")
        try assert(blocks[1].text == " world")
    }

    private static func testKeyboardMerge() throws {
        let first = UUID()
        let second = UUID()
        var blocks = [
            NoteBlock(id: first, kind: .paragraph, text: "One"),
            NoteBlock(id: second, kind: .paragraph, text: "Two")
        ]
        let result = BlockKeyboardEditing.mergeWithPrevious(blocks: &blocks, blockID: second)
        try assert(result != nil)
        try assert(blocks.count == 1)
        try assert(blocks[0].text == "OneTwo")
    }

    private static func testRichPasteHTML() throws {
        let html = "<p>First paragraph.</p><p>Second paragraph.</p>"
        let blocks = RichPasteImporter.blocksFromHTML(html)
        try assert(blocks != nil && (blocks?.count ?? 0) >= 2)
    }

    private static func testChunkerOmitsCode() throws {
        let docID = UUID()
        let blocks = [
            NoteBlock(kind: .paragraph, text: "Explain the API."),
            NoteBlock(kind: .code, text: "secret_token = 42", attributes: ["language": "swift"])
        ]
        let chunks = TextChunker.chunks(documentID: docID, title: "API", blocks: blocks)
        let embedJoined = chunks.map(\.text).joined(separator: "\n")
        try assert(!embedJoined.contains("secret_token"), "code must not appear in chunk embed text")
    }

    // MARK: - Helpers

    private static func assert(_ condition: Bool, _ message: String = "assertion failed") throws {
        if !condition { throw WritingTestError.assertion(message) }
    }

    private static func assertEqual<T: Equatable>(_ a: [T], _ b: [T]) throws {
        if a != b { throw WritingTestError.assertion("expected \(a), got \(b)") }
    }
}

enum WritingTestError: Error, LocalizedError {
    case assertion(String)
    var errorDescription: String? {
        switch self {
        case .assertion(let message): return message
        }
    }
}
