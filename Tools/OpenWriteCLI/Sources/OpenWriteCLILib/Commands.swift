import Foundation

public enum OpenWriteCLIRunner {
    public static func run(arguments: [String]) async {
        var args = arguments
        guard let command = args.first else {
            printUsage(toolName: currentToolName(fallback: "openwrite"))
            exit(1)
        }
        args.removeFirst()

        do {
            switch command {
            case "help", "-h", "--help":
                printUsage(toolName: currentToolName(fallback: "openwrite"))
            case "stats":
                try await runStats(args: args)
            case "index":
                try await runIndex(args: args)
            case "query":
                try await runQuery(args: args)
            case "test-queries":
                try await runQueryTests(args: args)
            default:
                fputs("Unknown command: \(command)\n", stderr)
                printUsage(toolName: currentToolName(fallback: "openwrite"))
                exit(1)
            }
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    /// Dedicated binaries pass a fixed subcommand (e.g. `openwrite-index` → `index`).
    public static func run(fixedCommand: String, arguments: [String]) async {
        let args = arguments
        if let first = args.first, first == "help" || first == "-h" || first == "--help" {
            printUsage(toolName: currentToolName(fallback: fixedCommand))
            return
        }
        do {
            switch fixedCommand {
            case "stats":
                try await runStats(args: args)
            case "index":
                try await runIndex(args: args)
            case "query":
                try await runQuery(args: args)
            case "test-queries":
                try await runQueryTests(args: args)
            default:
                fputs("Unknown tool: \(fixedCommand)\n", stderr)
                exit(1)
            }
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func currentToolName(fallback: String) -> String {
        let base = URL(fileURLWithPath: CommandLine.arguments.first ?? fallback)
            .deletingPathExtension()
            .lastPathComponent
        return base.isEmpty ? fallback : base
    }

    public static func printUsage(toolName: String) {
        let isMultiplexer = toolName == "openwrite"
        if isMultiplexer {
            print(
                """
                openwrite — local note index and hybrid retrieval

                Usage:
                  openwrite stats [--index PATH]
                  openwrite index [--notes PATH] [--index PATH]
                  openwrite query "…" [--limit N] [--keyword-only] [--index PATH]
                  openwrite test-queries [--notes PATH] [--index PATH] [--reindex] [--keyword-only]

                Dedicated tools (same flags):
                  openwrite-stats   openwrite-index   openwrite-query

                Defaults:
                  index  ~/Library/Application Support/openwrite/index.json
                  notes  ~/Library/Application Support/openwrite/notes/
                """
            )
        } else {
            print(
                """
                \(toolName) — OpenWrite CLI

                Run `\(toolName) --help` on the multiplexer `openwrite` for all commands.
                This binary runs the `\(toolName.replacingOccurrences(of: "openwrite-", with: ""))` subcommand directly.
                """
            )
        }
    }

    private static func runStats(args: [String]) async throws {
        let paths = CLIOptions.parse(args)
        let store = InMemoryVectorStore(persistenceURL: paths.indexURL)
        await store.loadFromDiskIfPresent()
        let count = await store.chunkCount
        let chunks = await store.allChunks()
        let docIDs = Set(chunks.map(\.documentID))
        print("Index: \(paths.indexURL.path)")
        print("Chunks: \(count)")
        print("Pages: \(docIDs.count)")
        if let sample = chunks.first {
            let preview = sample.text.prefix(120).replacingOccurrences(of: "\n", with: " ")
            print("Sample: [\(sample.documentTitle)] \(preview)…")
        }
    }

    private static func runIndex(args: [String]) async throws {
        let paths = CLIOptions.parse(args)
        let notesRoot = paths.notesURL
        guard FileManager.default.fileExists(atPath: notesRoot.path) else {
            throw CLIError.message("Notes folder not found: \(notesRoot.path)")
        }

        let store = InMemoryVectorStore(persistenceURL: paths.indexURL)
        await store.setPersistenceEnabled(false)
        await store.reset()

        let embedder = LocalHashEmbeddingService()
        let indexer = InMemoryIndexerService(vectorStore: store, embeddings: embedder)

        let files = VaultMarkdownCatalog.scan(vaultRoot: notesRoot)
        print("Indexing \(files.count) markdown file(s) from \(notesRoot.path)")

        for file in files {
            let blocks = try VaultMarkdownCatalog.loadBlocks(from: file)
            try await indexer.index(
                documentID: file.documentID,
                title: file.title,
                blocks: blocks,
                sourceFilename: file.sourceFilename,
                documentUpdatedAt: file.modifiedAt
            )
            print("  ✓ \(file.sourceFilename) (\(blocks.count) blocks)")
        }

        await store.setPersistenceEnabled(true)
        await store.flushPersistedIndex()
        let count = await store.chunkCount
        print("Wrote \(count) chunk(s) → \(paths.indexURL.path)")
    }

    private static func runQuery(args: [String]) async throws {
        let (paths, query, limit, keywordOnly) = try parseQueryArgs(args)
        guard let query, !query.isEmpty else {
            throw CLIError.message("Missing query text")
        }
        let hits = try await search(
            query: query,
            limit: limit,
            keywordOnly: keywordOnly,
            indexURL: paths.indexURL
        )
        printHits(query: query, hits: hits)
    }

    private static func runQueryTests(args: [String]) async throws {
        let paths = CLIOptions.parseForTests(args)
        let keywordOnly = args.contains("--keyword-only")
        let suite = QueryTestSuite.defaultSuite()

        print("Notes: \(paths.notesURL.path)")
        print("Index: \(paths.indexURL.path)\n")

        if args.contains("--reindex") || !FileManager.default.fileExists(atPath: paths.indexURL.path) {
            print("── Reindexing notes ──")
            try await runIndex(args: ["--notes", paths.notesURL.path, "--index", paths.indexURL.path])
            print()
        }

        var passed = 0
        var failed = 0

        for test in suite {
            let hits = try await search(
                query: test.query,
                limit: test.limit,
                keywordOnly: keywordOnly,
                indexURL: paths.indexURL
            )
            let ok = test.evaluate(hits: hits)
            let mark = ok ? "PASS" : "FAIL"
            print("[\(mark)] \(test.name)")
            print("  Q: \(test.query)")
            if hits.isEmpty {
                print("  (no hits)")
            } else {
                for (i, hit) in hits.prefix(3).enumerated() {
                    print("  \(i + 1). score=\(String(format: "%.3f", hit.score)) \(hit.documentTitle) — \(hit.snippet.prefix(80))…")
                }
            }
            if !ok, let expect = test.expectTopTitleContains {
                print("  Expected top title to contain: \(expect)")
            }
            print()
            if ok { passed += 1 } else { failed += 1 }
        }

        print("── \(passed) passed, \(failed) failed ──")
        if failed > 0 { exit(2) }
    }

    private static func search(
        query: String,
        limit: Int,
        keywordOnly: Bool,
        indexURL: URL
    ) async throws -> [RetrievalHit] {
        let store = InMemoryVectorStore(persistenceURL: indexURL)
        await store.loadFromDiskIfPresent()
        guard await store.chunkCount > 0 else {
            throw CLIError.message("Index is empty. Run: openwrite index")
        }

        let embedder = LocalHashEmbeddingService()
        let retrieval = HybridRetrievalService(vectorStore: store, embeddings: embedder)

        if keywordOnly {
            return try await retrieval.keywordSearch(query: query, limit: limit)
        }
        return try await retrieval.search(query: query, limit: limit)
    }

    private static func parseQueryArgs(_ args: [String]) throws -> (CLIOptions, String?, Int, Bool) {
        var remainder = args
        var limit = 8
        var keywordOnly = false
        if let limitIndex = remainder.firstIndex(of: "--limit"), limitIndex + 1 < remainder.count {
            if let value = Int(remainder[limitIndex + 1]) { limit = max(1, value) }
            remainder.remove(at: limitIndex + 1)
            remainder.remove(at: limitIndex)
        }
        if let ki = remainder.firstIndex(of: "--keyword-only") {
            keywordOnly = true
            remainder.remove(at: ki)
        }
        let parsed = CLIOptions.parse(remainder, collectingPositionals: true)
        let query = parsed.positionals.joined(separator: " ")
        return (parsed.options, query.isEmpty ? nil : query, limit, keywordOnly)
    }

    private static func printHits(query: String, hits: [RetrievalHit]) {
        print("Query: \(query)")
        if hits.isEmpty {
            print("(no hits)")
            return
        }
        for (i, hit) in hits.enumerated() {
            let file = hit.sourceFilename.map { " · \($0)" } ?? ""
            print("\(i + 1). [\(String(format: "%.3f", hit.score))] \(hit.documentTitle)\(file)")
            print("   \(hit.snippet)")
        }
    }
}

enum CLIError: Error, LocalizedError {
    case message(String)
    var errorDescription: String? {
        switch self {
        case .message(let text): return text
        }
    }
}

struct CLIOptions {
    let indexURL: URL
    let notesURL: URL

    static func parseForTests(_ args: [String]) -> CLIOptions {
        var parsed = parse(args)
        let hasNotes = args.contains("--notes") || args.contains("--vault")
        let hasIndex = args.contains("--index")
        if !hasNotes, FileManager.default.fileExists(atPath: fixtureNotesURL().path) {
            parsed = CLIOptions(indexURL: parsed.indexURL, notesURL: fixtureNotesURL())
        }
        if !hasIndex {
            parsed = CLIOptions(
                indexURL: fixtureIndexURL(),
                notesURL: parsed.notesURL
            )
        }
        return parsed
    }

    static func fixtureNotesURL() -> URL {
        URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("Fixtures/notes", isDirectory: true)
    }

    static func fixtureIndexURL() -> URL {
        fixtureNotesURL()
            .deletingLastPathComponent()
            .appendingPathComponent("test-index.json")
    }

    static func parse(_ args: [String]) -> CLIOptions {
        parse(args, collectingPositionals: false).options
    }

    static func parse(_ args: [String], collectingPositionals: Bool) -> (options: CLIOptions, positionals: [String]) {
        var indexURL = VectorStorePersistence.defaultURL
        var notesURL = defaultNotesURL()
        var positionals: [String] = []
        var i = 0
        while i < args.count {
            switch args[i] {
            case "--index" where i + 1 < args.count:
                indexURL = URL(fileURLWithPath: args[i + 1], isDirectory: false)
                i += 2
            case "--notes" where i + 1 < args.count:
                notesURL = URL(fileURLWithPath: args[i + 1], isDirectory: true)
                i += 2
            case "--vault" where i + 1 < args.count:
                fputs("Note: --vault is deprecated; use --notes\n", stderr)
                notesURL = URL(fileURLWithPath: args[i + 1], isDirectory: true)
                i += 2
            default:
                if collectingPositionals, !args[i].hasPrefix("--") {
                    positionals.append(args[i])
                }
                i += 1
            }
        }
        return (CLIOptions(indexURL: indexURL, notesURL: notesURL), positionals)
    }

    private static func defaultNotesURL() -> URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
            .appendingPathComponent("openwrite/notes", isDirectory: true)
    }
}

struct QueryTestCase {
    let name: String
    let query: String
    let limit: Int
    let expectTopTitleContains: String?

    func evaluate(hits: [RetrievalHit]) -> Bool {
        guard let expect = expectTopTitleContains else {
            return !hits.isEmpty
        }
        guard let top = hits.first else { return false }
        let haystack = "\(top.documentTitle) \(top.snippet)".lowercased()
        return haystack.contains(expect.lowercased())
    }
}

enum QueryTestSuite {
    static func defaultSuite() -> [QueryTestCase] {
        [
            QueryTestCase(
                name: "Welcome note",
                query: "local-first writing",
                limit: 5,
                expectTopTitleContains: "Welcome"
            ),
            QueryTestCase(
                name: "Filename retrieval",
                query: "Welcome.md notes search",
                limit: 5,
                expectTopTitleContains: "Welcome"
            ),
            QueryTestCase(
                name: "Temporal header (Updated line in chunk)",
                query: "yesterday news tumultuous",
                limit: 5,
                expectTopTitleContains: "Daily"
            ),
            QueryTestCase(
                name: "Developer workflow",
                query: "GitHub release candidate divergence",
                limit: 5,
                expectTopTitleContains: nil
            ),
            QueryTestCase(
                name: "Graph tour",
                query: "notes graph topology nodes",
                limit: 5,
                expectTopTitleContains: "Project"
            ),
            QueryTestCase(
                name: "Section breadcrumb",
                query: "heading hybrid cosine similarity",
                limit: 5,
                expectTopTitleContains: "Project"
            ),
            QueryTestCase(
                name: "Title lead (filename)",
                query: "Welcome.md",
                limit: 3,
                expectTopTitleContains: "Welcome"
            )
        ]
    }
}
