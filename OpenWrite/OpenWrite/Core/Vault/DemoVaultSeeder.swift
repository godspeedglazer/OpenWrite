import Foundation

/// Idempotent demo corpus — interconnected [[wikilinks]] for graph and object-type showcases.
enum DemoVaultSeeder {
    static let seedVersion = "2026-05-18-graph-v2"
    static let hubDocumentID = UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000001")!

    static func documents() -> [VaultDocument] {
        pageSpecs.map { spec in
            var doc = VaultDocument(
                id: spec.id,
                title: spec.title,
                pageType: spec.pageType,
                properties: PageProperties.defaults(for: spec.pageType, title: spec.title),
                rootBlocks: spec.blocks,
                metadata: [VaultDocument.MetadataKey.prefersBlockEditor: "true"],
                pageIcon: spec.icon,
                coverStyle: spec.cover
            )
            doc.assignVault(OpenWriteVault.demoID, demoSeed: true)
            return doc
        }
    }

    // MARK: - Page specs

    private struct PageSpec {
        let id: UUID
        let title: String
        let pageType: PageType
        let icon: String
        let cover: CoverStyle?
        let blocks: [NoteBlock]
    }

    private static func link(_ title: String) -> NoteBlock {
        NoteBlock(kind: .wikilink, text: title)
    }

    private static func para(_ text: String) -> NoteBlock {
        NoteBlock(kind: .paragraph, text: text)
    }

    private static func h2(_ text: String) -> NoteBlock {
        NoteBlock(kind: .heading2, text: text)
    }

    private static func h3(_ text: String) -> NoteBlock {
        NoteBlock(kind: .heading3, text: text)
    }

    private static func bullet(_ text: String) -> NoteBlock {
        NoteBlock(kind: .bullet, text: text)
    }

    private static func todo(_ text: String, checked: Bool = false) -> NoteBlock {
        NoteBlock.todoBlock(text: text, checked: checked)
    }

    private static func atlasClusterBlocks(node: Int, peers: [Int], blurb: String) -> [NoteBlock] {
        var blocks: [NoteBlock] = [
            para(blurb),
            link("OpenWrite Demo Space"),
            link("Graph Tour")
        ]
        for peer in peers {
            blocks.append(link("Graph Atlas \(String(format: "%02d", peer))"))
        }
        return blocks
    }

    private static let pageSpecs: [PageSpec] = [
        PageSpec(
            id: hubDocumentID,
            title: "OpenWrite Demo Space",
            pageType: .collection,
            icon: "◈",
            cover: .anytypeCalm,
            blocks: [
                NoteBlock(
                    kind: .callout,
                    text: "Explore this sample vault — every page is linked. Open Graph in the rail to see the topology.",
                    attributes: ["callout": "tip"]
                ),
                h2("Start here"),
                link("Graph Tour"),
                link("Wikilinks Primer"),
                link("Product Vision"),
                h2("By object type"),
                bullet("Notes: Local-First Principles, Writing Workflow, Backlink Demo"),
                bullet("Tasks: Ship v0.1, LM Studio Setup"),
                bullet("Journals: Daily Standup, Monday Reflection"),
                bullet("Projects: Product Vision, Research Pipeline, OpenWrite Roadmap"),
                bullet("References: Design Tokens, NDL Specification, Competitor Landscape"),
                bullet("Collections: Sprint Board, Literature Notes"),
                h2("Hub pages"),
                link("Sprint Board"),
                link("Literature Notes"),
                link("Feature Matrix"),
                h2("Graph atlas"),
                link("Graph Atlas 01"),
                link("Graph Atlas 06"),
                link("Graph Atlas 12")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000002")!,
            title: "Graph Tour",
            pageType: .note,
            icon: "◎",
            cover: .anytypeCalm,
            blocks: [
                h2("See your links"),
                para("Switch to Graph in the Objects section. Nodes grow with link count; edges follow [[wikilinks]]."),
                link("OpenWrite Demo Space"),
                link("Wikilinks Primer"),
                link("Backlink Demo"),
                h3("Try it"),
                todo("Open Graph from the rail", checked: false),
                todo("Click a node to jump to that page", checked: false),
                link("Product Vision")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000003")!,
            title: "Wikilinks Primer",
            pageType: .note,
            icon: "⛓",
            cover: nil,
            blocks: [
                para("Type [[Page Title]] in NDL or insert a wikilink block. Titles resolve case-insensitively within the active vault."),
                link("Backlink Demo"),
                link("Graph Tour"),
                link("Writing Workflow"),
                NoteBlock(kind: .code, text: "[[Graph Tour]]", attributes: ["language": "ndl"])
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000004")!,
            title: "Product Vision",
            pageType: .project,
            icon: "▣",
            cover: .anytypeCalm,
            blocks: [
                h2("Writing-first, AI-second"),
                para("One encrypted vault: NDL blocks, typed pages, optional LM Studio RAG — no cloud by default."),
                link("OpenWrite Roadmap"),
                link("Local-First Principles"),
                link("Competitor Landscape"),
                link("Feature Matrix")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000005")!,
            title: "Writing Workflow",
            pageType: .note,
            icon: "✎",
            cover: nil,
            blocks: [
                h2("Daily flow"),
                bullet("Capture in a note or journal"),
                bullet("Link context with [[wikilinks]]"),
                bullet("Review in Graph or object filters"),
                link("Wikilinks Primer"),
                link("Daily Standup"),
                link("Meeting Notes Template")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000006")!,
            title: "Daily Standup",
            pageType: .journal,
            icon: "☀",
            cover: nil,
            blocks: [
                h2("Today"),
                todo("Review Sprint Board", checked: true),
                todo("Ship typed page polish", checked: false),
                link("Ship v0.1"),
                link("Monday Reflection"),
                link("Sprint Board")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000007")!,
            title: "Monday Reflection",
            pageType: .journal,
            icon: "☾",
            cover: nil,
            blocks: [
                para("Weekly retro — what linked ideas survived the sprint?"),
                link("Daily Standup"),
                link("Sprint Board"),
                link("Product Vision")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000008")!,
            title: "Ship v0.1",
            pageType: .task,
            icon: "☑",
            cover: nil,
            blocks: [
                h2("Milestone"),
                todo("Demo vault + per-vault object filters", checked: true),
                todo("Graph layout polish", checked: false),
                todo("Real encrypted bundle on disk", checked: false),
                link("OpenWrite Roadmap"),
                link("Feature Matrix"),
                link("Design Tokens")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000009")!,
            title: "LM Studio Setup",
            pageType: .task,
            icon: "◇",
            cover: nil,
            blocks: [
                para("Configure local inference in Settings — retrieval stays on-device."),
                link("Research Pipeline"),
                link("Privacy Posture"),
                todo("Point base URL at localhost:1234", checked: false)
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-00000000000A")!,
            title: "Research Pipeline",
            pageType: .project,
            icon: "◉",
            cover: nil,
            blocks: [
                h2("RAG stack"),
                bullet("Chunk vault documents"),
                bullet("Embed via LM Studio"),
                bullet("Hybrid rank for chat + Related"),
                link("LM Studio Setup"),
                link("Literature Notes"),
                link("NDL Specification")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-00000000000B")!,
            title: "OpenWrite Roadmap",
            pageType: .project,
            icon: "→",
            cover: .anytypeCalm,
            blocks: [
                bullet("Phase 1: in-memory vault + shell"),
                bullet("Phase 2: disk bundle + encryption"),
                bullet("Phase 3: citations + streaming RAG"),
                link("Product Vision"),
                link("Feature Matrix"),
                link("Ship v0.1")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-00000000000C")!,
            title: "Design Tokens",
            pageType: .reference,
            icon: "◐",
            cover: nil,
            blocks: [
                para("Serif typography, teal accent, custom rail — see DesignTokens.swift and OWTypography."),
                link("Typed Pages"),
                link("Product Vision")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-00000000000D")!,
            title: "NDL Specification",
            pageType: .reference,
            icon: "¶",
            cover: nil,
            blocks: [
                para("Note Design Language v0 — block kinds, properties, wikilinks in docs/NDL/."),
                link("Wikilinks Primer"),
                link("Research Pipeline")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-00000000000E")!,
            title: "Competitor Landscape",
            pageType: .reference,
            icon: "⊞",
            cover: nil,
            blocks: [
                bullet("Anytype — object graph aesthetics (inspiration only)"),
                bullet("Logseq — outliner + wikilinks"),
                bullet("Reor — local RAG posture"),
                link("Product Vision"),
                link("Local-First Principles")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-00000000000F")!,
            title: "Feature Matrix",
            pageType: .reference,
            icon: "▤",
            cover: nil,
            blocks: [
                para("357-row parity matrix in docs/FeatureParityMatrix.md tracks done / partial / planned."),
                link("OpenWrite Roadmap"),
                link("Ship v0.1"),
                link("OpenWrite Demo Space")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000010")!,
            title: "Local-First Principles",
            pageType: .note,
            icon: "⌂",
            cover: nil,
            blocks: [
                para("Your corpus stays on this Mac. No account, no sync-by-default."),
                link("Privacy Posture"),
                link("Product Vision"),
                link("Writing Workflow")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000011")!,
            title: "Privacy Posture",
            pageType: .note,
            icon: "⛨",
            cover: nil,
            blocks: [
                para("ADR-0001: local-only defaults. AI runs when you configure LM Studio."),
                link("Local-First Principles"),
                link("LM Studio Setup")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000012")!,
            title: "Backlink Demo",
            pageType: .note,
            icon: "↩",
            cover: nil,
            blocks: [
                para("Pages that link here appear in the backlink index. This note is linked from Graph Tour and Wikilinks Primer."),
                link("Wikilinks Primer"),
                link("Graph Tour"),
                link("Typed Pages")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000013")!,
            title: "Typed Pages",
            pageType: .note,
            icon: "▦",
            cover: nil,
            blocks: [
                para("PageType drives inspector schema — note, task, journal, project, reference, collection."),
                link("Design Tokens"),
                link("Backlink Demo"),
                link("Sprint Board")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000014")!,
            title: "Sprint Board",
            pageType: .collection,
            icon: "▥",
            cover: nil,
            blocks: [
                h2("This sprint"),
                link("Ship v0.1"),
                link("Daily Standup"),
                link("Graph Tour"),
                link("LM Studio Setup"),
                link("OpenWrite Demo Space")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000015")!,
            title: "Literature Notes",
            pageType: .collection,
            icon: "📚",
            cover: nil,
            blocks: [
                para("Collection of references and reading notes."),
                link("Competitor Landscape"),
                link("NDL Specification"),
                link("Research Pipeline")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000016")!,
            title: "Meeting Notes Template",
            pageType: .note,
            icon: "◷",
            cover: nil,
            blocks: [
                h2("Attendees"),
                bullet("You"),
                h2("Agenda"),
                link("Sprint Board"),
                link("Product Vision"),
                h2("Actions"),
                link("Ship v0.1")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000017")!,
            title: "Capture Inbox",
            pageType: .note,
            icon: "◎",
            cover: nil,
            blocks: [
                para("Quick ideas land here before you file them into projects or journals."),
                link("Writing Workflow"),
                link("Wikilinks Primer"),
                link("OpenWrite Demo Space")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000018")!,
            title: "Block Editor Tour",
            pageType: .note,
            icon: "▤",
            cover: nil,
            blocks: [
                para("Headings, todos, callouts, and code blocks live in the NDL tree."),
                link("NDL Specification"),
                link("Design Tokens"),
                link("Graph Tour")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000019")!,
            title: "Themes Gallery",
            pageType: .reference,
            icon: "◑",
            cover: .anytypeCalm,
            blocks: [
                para("Nine palettes — cycle from the rail footer or pick in Settings."),
                link("Design Tokens"),
                link("Product Vision")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-00000000001A")!,
            title: "Inspector & AI",
            pageType: .note,
            icon: "✦",
            cover: nil,
            blocks: [
                para("Chat, Related, and Past Writes live in the trailing strip — collapsed by default."),
                link("Research Pipeline"),
                link("Privacy Posture"),
                link("LM Studio Setup")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-00000000001B")!,
            title: "Database Presets",
            pageType: .reference,
            icon: "▦",
            cover: nil,
            blocks: [
                para("Universal databases (snippets, reading list) sit beside typed pages in the rail."),
                link("Feature Matrix"),
                link("OpenWrite Demo Space")
            ]
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000020")!,
            title: "Graph Atlas 01",
            pageType: .note,
            icon: "①",
            cover: nil,
            blocks: atlasClusterBlocks(node: 1, peers: [2, 3, 6], blurb: "Atlas ring node — drag nodes in Graph to test layout.")
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000021")!,
            title: "Graph Atlas 02",
            pageType: .note,
            icon: "②",
            cover: nil,
            blocks: atlasClusterBlocks(node: 2, peers: [1, 3, 7], blurb: "Second atlas node.")
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000022")!,
            title: "Graph Atlas 03",
            pageType: .note,
            icon: "③",
            cover: nil,
            blocks: atlasClusterBlocks(node: 3, peers: [2, 4, 8], blurb: "Third atlas node.")
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000023")!,
            title: "Graph Atlas 04",
            pageType: .note,
            icon: "④",
            cover: nil,
            blocks: atlasClusterBlocks(node: 4, peers: [3, 5, 9], blurb: "Fourth atlas node.")
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000024")!,
            title: "Graph Atlas 05",
            pageType: .note,
            icon: "⑤",
            cover: nil,
            blocks: atlasClusterBlocks(node: 5, peers: [4, 6, 10], blurb: "Fifth atlas node.")
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000025")!,
            title: "Graph Atlas 06",
            pageType: .note,
            icon: "⑥",
            cover: nil,
            blocks: atlasClusterBlocks(node: 6, peers: [5, 7, 11], blurb: "Sixth atlas node.")
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000026")!,
            title: "Graph Atlas 07",
            pageType: .note,
            icon: "⑦",
            cover: nil,
            blocks: atlasClusterBlocks(node: 7, peers: [6, 8, 12], blurb: "Seventh atlas node.")
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000027")!,
            title: "Graph Atlas 08",
            pageType: .note,
            icon: "⑧",
            cover: nil,
            blocks: atlasClusterBlocks(node: 8, peers: [7, 9, 1], blurb: "Eighth atlas node.")
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000028")!,
            title: "Graph Atlas 09",
            pageType: .note,
            icon: "⑨",
            cover: nil,
            blocks: atlasClusterBlocks(node: 9, peers: [8, 10, 2], blurb: "Ninth atlas node.")
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-000000000029")!,
            title: "Graph Atlas 10",
            pageType: .note,
            icon: "⑩",
            cover: nil,
            blocks: atlasClusterBlocks(node: 10, peers: [9, 11, 3], blurb: "Tenth atlas node.")
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-00000000002A")!,
            title: "Graph Atlas 11",
            pageType: .note,
            icon: "⑪",
            cover: nil,
            blocks: atlasClusterBlocks(node: 11, peers: [10, 12, 4], blurb: "Eleventh atlas node.")
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-00000000002B")!,
            title: "Graph Atlas 12",
            pageType: .note,
            icon: "⑫",
            cover: nil,
            blocks: atlasClusterBlocks(node: 12, peers: [11, 1, 5], blurb: "Twelfth atlas node — completes the ring.")
        ),
        PageSpec(
            id: UUID(uuidString: "E1C00002-7B2A-4E8F-9D01-00000000001C")!,
            title: "Welcome Tour",
            pageType: .note,
            icon: "◇",
            cover: nil,
            blocks: [
                para("Your primary vault keeps Welcome to OpenWrite separate from this demo corpus."),
                link("OpenWrite Demo Space"),
                link("Graph Tour"),
                NoteBlock(
                    kind: .callout,
                    text: "Switch vaults from the space row at the top of the rail.",
                    attributes: ["callout": "note"]
                )
            ]
        )
    ]

    static let seededDocumentIDs: Set<UUID> = Set(pageSpecs.map(\.id))

    static func isDemoInstalled(in documents: [VaultDocument]) -> Bool {
        documents.contains { $0.id == hubDocumentID && $0.belongsToVault(OpenWriteVault.demoID) }
    }
}
