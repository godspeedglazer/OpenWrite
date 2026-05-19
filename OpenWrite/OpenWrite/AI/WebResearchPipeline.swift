import Foundation

// MARK: - Corpus chunks (RAG-style web excerpts)

/// One searchable slice of a fetched page — cited as `[web:UUID]` in prompts.
struct WebCorpusChunk: Identifiable, Sendable, Hashable {
    let id: UUID
    let pageID: UUID
    let pageURL: URL
    let pageTitle: String?
    let chunkIndex: Int
    let text: String
}

/// UI + transcript metadata for verified web sources.
struct WebSourceReference: Identifiable, Sendable, Hashable {
    let id: UUID
    let url: URL
    let title: String?
    let chunkCount: Int
    let fetchedAt: Date

    init(page: WebPageSnapshot, chunkCount: Int) {
        self.id = page.id
        self.url = page.finalURL
        self.title = page.title
        self.chunkCount = chunkCount
        self.fetchedAt = page.fetchedAt
    }
}

struct WebResearchProfile: Sendable {
    let maxURLsPerPass: Int
    let maxPasses: Int
    let expandQueries: Bool

    /// Default chat: one search pass, few URLs.
    static let standard = WebResearchProfile(
        maxURLsPerPass: AISafetyLimits.maxWebURLsPerMessage,
        maxPasses: 1,
        expandQueries: false
    )

    /// Research Q&A: multi-hop search + broader fetch budget.
    static let deep = WebResearchProfile(
        maxURLsPerPass: AISafetyLimits.maxWebURLsPerResearchPass,
        maxPasses: AISafetyLimits.maxWebResearchPasses,
        expandQueries: true
    )
}

struct WebResearchResult: Sendable {
    let pages: [WebPageSnapshot]
    let chunks: [WebCorpusChunk]
    let sources: [WebSourceReference]
    let passesCompleted: Int
}

// MARK: - Chunker

enum WebCorpusChunker {
    static func chunks(from pages: [WebPageSnapshot]) -> [WebCorpusChunk] {
        var result: [WebCorpusChunk] = []
        for page in pages {
            let pieces = splitPageText(page.text, maxChars: AISafetyLimits.maxWebChunkChars)
                .prefix(AISafetyLimits.maxWebChunksPerPage)
            for (index, piece) in pieces.enumerated() {
                let trimmed = piece.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                result.append(
                    WebCorpusChunk(
                        id: UUID(),
                        pageID: page.id,
                        pageURL: page.finalURL,
                        pageTitle: page.title,
                        chunkIndex: index,
                        text: trimmed
                    )
                )
            }
        }
        return result
    }

    private static func splitPageText(_ text: String, maxChars: Int) -> [String] {
        let paragraphs = text
            .components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !paragraphs.isEmpty else { return [text] }

        var chunks: [String] = []
        var buffer = ""
        for paragraph in paragraphs {
            if buffer.isEmpty {
                buffer = paragraph
            } else if buffer.count + 2 + paragraph.count <= maxChars {
                buffer += "\n\n" + paragraph
            } else {
                chunks.append(buffer)
                buffer = paragraph
            }
            if buffer.count > maxChars {
                chunks.append(String(buffer.prefix(maxChars)))
                buffer = String(buffer.dropFirst(maxChars))
            }
        }
        if !buffer.isEmpty { chunks.append(buffer) }
        return chunks.isEmpty ? [text] : chunks
    }
}

// MARK: - Query expansion (heuristic follow-up searches)

enum WebQueryExpander {
    static func followUpQueries(base: String, pages: [WebPageSnapshot], max: Int = 2) -> [String] {
        guard let sanitized = AIInput.sanitizeQuery(base) else { return [] }
        var queries: [String] = []
        var seen = Set<String>()

        func append(_ q: String) {
            let key = q.lowercased()
            guard seen.insert(key).inserted else { return }
            queries.append(q)
        }

        let lower = sanitized.lowercased()
        if lower.contains("news") || lower.contains("yesterday") || lower.contains("today") {
            let formatter = DateFormatter()
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date()) ?? Date()
            append("\(sanitized) \(formatter.string(from: yesterday))")
        }

        for page in pages.prefix(3) {
            guard queries.count < max else { break }
            if let title = page.title?.trimmingCharacters(in: .whitespacesAndNewlines), title.count >= 8 {
                append("\(sanitized) \(title)")
            }
        }

        if queries.count < max, !lower.contains("latest") {
            append("\(sanitized) latest")
        }

        return Array(queries.prefix(max))
    }
}

// MARK: - Multi-hop pipeline

/// Orchestrates search → fetch → optional follow-up search (verified-source research).
enum WebResearchPipeline {
    static func run(
        query: String,
        explicitURLs: [URL],
        fetcher: WebFetchService,
        profile: WebResearchProfile
    ) async -> WebResearchResult {
        var pages: [WebPageSnapshot] = []
        var seenURLKeys = Set<String>()
        var passes = 0

        func ingest(_ urls: [URL]) async {
            let novel = urls.filter { seenURLKeys.insert($0.absoluteString).inserted }
            guard !novel.isEmpty else { return }
            let batch = Array(novel.prefix(profile.maxURLsPerPass))
            let fetched = await fetcher.fetchPages(urls: batch)
            pages.append(contentsOf: fetched)
        }

        passes += 1
        var urls = explicitURLs
        if urls.isEmpty {
            urls = await fetcher.resolveSearchURLs(for: query, limit: profile.maxURLsPerPass)
        }
        await ingest(urls)

        if profile.expandQueries, profile.maxPasses > 1, passes < profile.maxPasses {
            let thin = pages.isEmpty || pages.allSatisfy { $0.text.count < 600 }
            let expansions = WebQueryExpander.followUpQueries(base: query, pages: pages)
            if thin || !expansions.isEmpty {
                passes += 1
                for subquery in expansions {
                    let more = await fetcher.resolveSearchURLs(for: subquery, limit: profile.maxURLsPerPass)
                    await ingest(more)
                }
            }
        }

        let chunks = WebCorpusChunker.chunks(from: pages)
        let chunksPerPage = Dictionary(grouping: chunks, by: \.pageID).mapValues(\.count)
        let sources = pages.map { page in
            WebSourceReference(page: page, chunkCount: chunksPerPage[page.id] ?? 1)
        }

        return WebResearchResult(
            pages: pages,
            chunks: chunks,
            sources: sources,
            passesCompleted: passes
        )
    }
}

// MARK: - Session cache (multi-turn research without re-fetching)

actor WebResearchSessionCache {
    private var pagesByURL: [String: WebPageSnapshot] = [:]

    func merge(_ pages: [WebPageSnapshot]) {
        for page in pages {
            pagesByURL[page.finalURL.absoluteString] = page
        }
    }

    func pages(matching query: String, limit: Int) -> [WebPageSnapshot] {
        let terms = query.lowercased()
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .filter { $0.count >= 4 }
        guard !terms.isEmpty else { return [] }
        return pagesByURL.values
            .filter { page in
                let haystack = "\(page.title ?? "") \(page.text)".lowercased()
                return terms.contains { haystack.contains($0) }
            }
            .prefix(limit)
            .map { $0 }
    }
}
