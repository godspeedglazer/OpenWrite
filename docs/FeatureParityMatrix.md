# OpenWrite Feature Parity Matrix

**Version:** 0.1  
**Last updated:** 2026-05-17  
**Purpose:** Track competitive parity across Logseq, AFFiNE, Anytype, Reor, and Obsidian; map every OpenWrite row to a Phase 2 epic (E-01…E-10) or ADR.

---

## How to read this document

### Competitor columns (Logseq · AFFiNE · Anytype · Reor · Obsidian)

| Symbol | Meaning |
|--------|---------|
| **●** | Strong / first-class in product |
| **◐** | Partial, plugin, or edition-limited |
| **○** | Weak, missing, or niche |
| **—** | Not applicable or not a product focus |

### OpenWrite column

| Status | Meaning |
|--------|---------|
| **done** | Implemented on `main` (usable, not necessarily polished) |
| **partial** | Scaffold, stub, or incomplete UX |
| **planned** | In Phase 2 epics or master plan v1/v2 |
| **wont** | Explicit non-goal |

### Pass 1 column (research absorption pass)

| Mark | Meaning |
|------|---------|
| **✓** | Absorbed in Phase 1 pass — types, protocols, partial UI, or docs |
| **◐** | Partial scaffold only |
| **—** | Not started in pass 1 |

**Feature docs:** [VaultEncryption](features/VaultEncryption.md) · [GraphView](features/GraphView.md) · [Workbench](features/Workbench.md) · [ImportExport](features/ImportExport.md) · [PastWrites](features/PastWrites.md)

---

## Pass 1 absorption summary

| Area | Pass 1 absorbed | Still missing (Phase 2) |
|------|-----------------|-------------------------|
| Vault / crypto | `EncryptionService`, `VaultStore.sealedPayload`, models | CryptoKit, `.openwrite` disk, Keychain unlock |
| NDL / editor | `NoteBlock`, `NDLParser` partial, `EditorView` | Block tree UI, outliner ops, E-02 kinds |
| Types | `PageType`, `PageProperties`, property inspector UI | Relation graph, templates UX polish |
| AI | `LMStudioClient` health, `RAGService` stub, chat/related UI | Embeddings, answers, citations |
| Search / index | `IndexerService`, `HybridRanker`, `InMemoryVectorStore` stubs | FSEvents, persisted index |
| Graph | `BacklinkIndex` stub, sidebar enum | `GraphView`, layout, inspector backlinks |
| Workbench | `WorkbenchState`, inspector tabs, `DesignTokens` | Full split shell, tabs, collections |
| Capture | `QuickCaptureController` stub | Global hotkey, inbox note |
| Import | `MarkdownImporter` stub | Obsidian folder import |
| Past Writes | In-memory module + timeline UI | Persistence, rem+ parser |
| Product docs | Master plan, epics, ADRs, NDL spec, **this matrix** | Per-feature doc completion |

---

## Matrix index

1. [Editor & blocks](#1-editor--blocks) · 2. [Outliner](#2-outliner--document-structure) · 3. [Graph & linking](#3-graph--linking) · 4. [Types & properties](#4-types-properties--metadata) · 5. [AI & RAG](#5-ai-rag--assistants) · 6. [Search](#6-search--indexing) · 7. [Sync](#7-sync--collaboration) · 8. [Capture](#8-capture--inbox) · 9. [Canvas](#9-canvas-whiteboard--databases) · 10. [Plugins](#10-plugins--extensibility) · 11. [Privacy](#11-privacy--security) · 12. [Import & export](#12-import--export) · 13. [Publishing](#13-publishing--sharing) · 14. [Workbench](#14-workbench--navigation) · 15. [Platform](#15-platform--os-integration) · 16. [Mobile](#16-mobile--cross-platform) · 17. [Tasks](#17-tasks-journal--workflows) · 18. [Media](#18-media-embeds--assets) · 19. [Settings](#19-settings-themes--customization) · 20. [Performance](#20-performance-scale--reliability) · 21. [Differentiators](#21-openwrite-differentiators)

---

## 1. Editor & blocks

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Block-based document model | ● | ● | ● | ◐ | ◐ | **partial** | ✓ | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Native block UUID per block | ● | ● | ● | ○ | ◐ | **partial** | ✓ | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Nested block children tree | ● | ● | ● | ○ | ◐ | **partial** | ◐ | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Outliner indent/outdent | ● | ◐ | ◐ | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Drag-and-drop block reorder | ● | ● | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Slash command menu | ● | ● | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Markdown shortcuts while typing | ● | ● | ◐ | ● | ● | **partial** | ◐ | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| WYSIWYG inline formatting | ◐ | ● | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Headings H1–H3 | ● | ● | ● | ◐ | ● | **partial** | ✓ | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Bulleted lists | ● | ● | ● | ◐ | ● | **partial** | ✓ | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Numbered lists | ● | ● | ● | ◐ | ● | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Todo / checkbox blocks | ● | ● | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Quote blocks | ● | ● | ● | ◐ | ● | **partial** | ✓ | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Code blocks + syntax highlight | ● | ● | ● | ◐ | ● | **partial** | ◐ | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Divider / horizontal rule | ● | ● | ● | ○ | ● | **partial** | ✓ | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Callout / admonition blocks | ● | ● | ◐ | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Table blocks | ◐ | ● | ● | ○ | ◐ | **planned** | — | v2 NDL |
| Math / LaTeX blocks | ● | ◐ | ◐ | ○ | ● | **planned** | — | v2 NDL |
| Mermaid / diagram embeds | ● | ◐ | ○ | ○ | ◐ | **planned** | — | v2 NDL |
| Collapsible blocks | ● | ◐ | ◐ | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Block references ((())) | ● | ◐ | ● | ○ | ● | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Embeds / transclusion | ● | ● | ● | ○ | ● | **planned** | — | v2 NDL |
| PDF embed in editor | ◐ | ● | ● | ○ | ◐ | **planned** | — | v2 |
| Multi-column layout | ○ | ● | ◐ | ○ | ○ | **wont** | — | v2+ |
| Real-time collaboration cursors | ◐ | ● | ● | ○ | ○ | **wont** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| Version history per block | ◐ | ● | ◐ | ○ | ◐ | **planned** | — | v2 |
| Undo/redo stack | ● | ● | ● | ◐ | ● | **partial** | ◐ | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Focus mode / zen writing | ◐ | ◐ | ○ | ○ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Typewriter scroll | ○ | ○ | ○ | ○ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Vim keybindings | ◐ | ○ | ○ | ○ | ● | **wont** | — | native HIG |
| RTL / bidi text | ◐ | ◐ | ◐ | ○ | ◐ | **planned** | — | v2-a11y |
| Spellcheck native | ● | ● | ● | ◐ | ● | **planned** | — | AppKit bridge |
| Word count / reading time | ◐ | ◐ | ◐ | ○ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Canonical schema not Markdown | ◐ | ● | ● | ○ | ○ | **done** | ✓ | [NDL spec](NDL/Specification.md) |
| Lossless parse serialize round-trip | ● | ● | ● | ◐ | ◐ | **partial** | ◐ | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Block validator / invariants | ● | ● | ● | ○ | ○ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Web-based editor Electron | ● | ● | ● | ● | ● | **wont** | — | SwiftUI |
| BlockNote ProseMirror stack | ○ | ● | ○ | ● | ○ | **wont** | — | [ADR-0003](adr/0003-reor-rag-in-swift.md) |
| Toggle heading blocks | ● | ◐ | ◐ | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Properties block in body | ● | ◐ | ● | ○ | ● | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |

## 2. Outliner & document structure

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Zoom into block subtree | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Breadcrumb block path | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Journal pages daily | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Fractional indexing order key | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Soft delete recycle bin | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Duplicate subtree | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Move block across pages | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Fold unfold children | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Outline sidebar for page | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| SQLite authoritative store | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Markdown files on disk as source | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Flat file per page export | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Namespace folder hierarchy | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Daily note auto-create | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Page icons cover images | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Full-page width toggle | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Outliner-first navigation | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Page equals document root | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| [[wikilink]] syntax | ● | ● | ● | ● | ● | **partial** | ✓ | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Backlink index in Swift | ● | ◐ | ● | ◐ | ◐ | **partial** | ✓ | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Templates for new pages | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |
| Block-level zoom breadcrumb | ● | ◐ | ● | ○ | ◐ | **planned** | — | [E-02](RoadmapEpics.md#e-02-ndl-editor-v1) |

## 3. Graph & linking

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Unresolved link stubs | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Backlinks panel | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Global graph view | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Local graph neighborhood | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Block-level graph | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Typed relation edges | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Graph filters tags type | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Graph search highlight | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Force-directed layout | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Hierarchical layout | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Click node open page | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Alias links | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Namespaced links | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Link autocomplete | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Orphan node detection | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Graph export PNG SVG | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Datalog query engine | ● | ● | ● | ◐ | ● | **wont** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Graph persisted index | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Spaces multi-graph | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Object graph Anytype | ● | ● | ● | ◐ | ● | **wont** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Mention people | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| URL auto-linking | ● | ● | ● | ◐ | ● | **planned** | — | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |
| Semantic related notes vector | ● | ● | ● | ◐ | ● | **partial** | ✓ | [E-06](RoadmapEpics.md#e-06-backlinks-graph) |

## 4. Types properties & metadata

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Object types templates | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Note Task Reference types | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Journal page type | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Project page type | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Custom type designer UI | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Relations between objects | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Rollups lookups | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Kanban view | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Calendar view | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Gallery view | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Table database view | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Tags property | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Date due date fields | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Status field task | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| URL source fields | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Property inspector panel | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Type picker on create | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| YAML frontmatter import | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Saved filters smart collections | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Unique object ID Any-ID | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Sets collections | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Form view on type | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Required properties validation | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Multi-select enums | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Icon per type | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |

## 5. AI RAG & assistants

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Local LLM integration | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| LM Studio OpenAI API | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Ollama support | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Cloud AI default | ◐ | ◐ | ◐ | ● | ◐ | **wont** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| Vault Q&A chat | ◐ | ◐ | ◐ | ● | ◐ | **partial** | ✓ | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Citations to block IDs | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Streaming chat responses | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Per-note embeddings | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Related notes sidebar | ◐ | ◐ | ◐ | ● | ◐ | **partial** | ✓ | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Hybrid vector keyword RAG | ◐ | ◐ | ◐ | ● | ◐ | **partial** | ✓ | [ADR-0003](adr/0003-reor-rag-in-swift.md) |
| Agent tools search create | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Inline continue writing | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Summarize selection | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| AI rewrite tone | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Prompt templates library | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Model picker UI | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Health check connectivity | ◐ | ◐ | ◐ | ● | ◐ | **partial** | ✓ | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Embedding provider protocol | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| RAG safety limits token cap | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Dual-generator product model | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| On-device model bundled | ◐ | ◐ | ◐ | ● | ◐ | **wont** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| PostHog default telemetry in AI | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Writing assistant shipped | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Chat history per vault | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Filter RAG to folder tag | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Past Writes context for RAG | ◐ | ◐ | ◐ | ● | ◐ | **planned** | — | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |

## 6. Search & indexing

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Full-text search | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Semantic vector search | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Hybrid rank BM25 cosine | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Search in page titles only | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Search block content | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Quick switcher | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Command palette | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| FSEvents background indexer | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Chunk by heading Reor | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| LanceDB vector store | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| SQLite vector extension | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| In-memory vector store dev | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Index rebuild command | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Spotlight integration | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Regex search | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| In-memory vector store dev | ○ | ○ | ○ | ◐ | ○ | **partial** | ✓ | [E-04](RoadmapEpics.md#e-04-fsevents-indexer) |
| Search result snippets | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Hybrid rank BM25 cosine | ○ | ◐ | ◐ | ● | ◐ | **partial** | ✓ | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Saved searches | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |
| Indexer remove on delete | ● | ● | ● | ● | ● | **planned** | — | [E-05](RoadmapEpics.md#e-05-hybrid-search) |

## 7. Sync & collaboration

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Cloud sync built-in | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| P2P local mesh sync | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| E2E encrypted sync | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| Multi-device real-time | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| Conflict resolution UI | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| Shared vault team space | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| Export vault for backup | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| iCloud Drive raw folder sync | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| Git-based sync Obsidian | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| Offline-first default | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| Account Any-ID required | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| Spaces workspaces | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| CRDT Yjs collaboration | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| Versioned sync history | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| Read-only published link | ◐ | ● | ● | ○ | ◐ | **planned** | — | [ADR-0001](adr/0001-local-only-architecture.md) |

## 8. Capture & inbox

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Global quick capture hotkey | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| Inbox note fleeting note | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| Menubar capture app | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| Minimal capture window | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| Capture to inbox section | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| Voice memo capture | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| Web clipper extension | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| Screenshot to note | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| Mobile share sheet | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| Capture to inbox section | ● | ● | ● | ◐ | ◐ | **planned** | ✓ | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| QuickCaptureController seam | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| Append to daily journal | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| Capture templates | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| QuickCaptureController seam | ○ | ○ | ○ | ○ | ○ | **partial** | ✓ | [E-09](RoadmapEpics.md#e-09-fast-capture) |
| Buffer-style queue | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-09](RoadmapEpics.md#e-09-fast-capture) |

## 9. Canvas whiteboard & databases

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Infinite canvas whiteboard | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |
| Edgeless mode per page | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |
| Draw pen tools | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |
| Mind map on canvas | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |
| Database block on canvas | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |
| Kanban on canvas | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |
| PDF annotation canvas | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |
| Excalidraw embed | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |
| BlockSuite runtime | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |
| Simple diagram blocks in NDL | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |
| AFFiNE Cloud backend | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |
| Linked doc cards on board | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |
| Presentation mode | ◐ | ● | ● | ◐ | ◐ | **wont** | — | [Roadmap OOS](RoadmapEpics.md#out-of-scope-phase-2) |

## 10. Plugins & extensibility

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Plugin marketplace | ◐ | ● | ● | ◐ | ◐ | **wont** | — | v2 plugins |
| Community plugins | ◐ | ● | ● | ◐ | ◐ | **wont** | — | v2 plugins |
| JavaScript plugin API | ◐ | ● | ● | ◐ | ◐ | **wont** | — | v2 plugins |
| Templater scripts | ◐ | ● | ● | ◐ | ◐ | **wont** | — | v2 plugins |
| Dataview queries | ◐ | ● | ● | ◐ | ◐ | **wont** | — | v2 plugins |
| Custom CSS themes | ◐ | ● | ● | ◐ | ◐ | **wont** | — | v2 plugins |
| API for external tools | ◐ | ● | ● | ◐ | ◐ | **wont** | — | v2 plugins |
| Core features without plugins | ○ | ◐ | ● | ● | ○ | **planned** | ✓ | [OpenWriteMasterPlan](OpenWriteMasterPlan.md) |
| Obsidian API compatibility | ◐ | ● | ● | ◐ | ◐ | **wont** | — | v2 plugins |
| Logseq plugins | ◐ | ● | ● | ◐ | ◐ | **wont** | — | v2 plugins |
| Zapier integrations | ◐ | ● | ● | ◐ | ◐ | **wont** | — | v2 plugins |

## 11. Privacy & security

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Encryption at rest | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| E2E encrypted spaces | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| Keychain key storage | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| Lock vault on sleep | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| Passphrase unlock | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| Touch ID unlock | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| No default telemetry | ◐ | ◐ | ● | ○ | ◐ | **done** | ✓ | [ADR-0001](adr/0001-local-only-architecture.md) |
| Opt-in analytics | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| Local-only AI default | ◐ | ◐ | ● | ○ | ◐ | **done** | ✓ | [ADR-0001](adr/0001-local-only-architecture.md) |
| Sandboxed network LM only | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| Plaintext md vault default | ◐ | ◐ | ● | ○ | ◐ | **wont** | — | [ADR-0001](adr/0001-local-only-architecture.md) |
| ASAL Anytype code isolation | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| AGPL clean-room Reor Logseq | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| Encrypted search index | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| Secure delete wipe vault | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| Export warning plaintext | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| Privacy policy in-app | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| Screen capture of vault UI | ◐ | ◐ | ● | ○ | ◐ | **planned** | — | [E-01](RoadmapEpics.md#e-01-vault-encryption-v1) |
| rem+ data optional import | ◐ | ◐ | ● | ○ | ◐ | **partial** | ✓ | [PastWrites](features/PastWrites.md) |

## 12. Import & export

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Import Markdown file | ● | ● | ● | ● | ● | **partial** | ✓ | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Import Obsidian vault folder | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Import Logseq folder | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Import Reor vault | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Import Anytype | ● | ● | ● | ● | ● | **wont** | — | ASAL — no import |
| Export single note MD | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Export vault folder MD | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Export PDF | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Export HTML publish view | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Pandoc integration | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Attachment import | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Wikilink preservation on import | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Frontmatter to properties | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Import report errors UI | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Duplicate title handling | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| MarkdownImporter seam | ● | ● | ● | ● | ● | **partial** | ✓ | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| NDL as import target | ● | ● | ● | ● | ● | **done** | ✓ | [NDL spec](NDL/Specification.md) |
| Lossless Obsidian round-trip | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Publish template export | ● | ● | ● | ● | ● | **planned** | — | [E-07](RoadmapEpics.md#e-07-import-markdown--obsidian) |

## 13. Publishing & sharing

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Blog newsletter export | ○ | ● | ◐ | ○ | ◐ | **planned** | — | [E-10](RoadmapEpics.md#e-10-publish-pipeline-stub) |
| Social thread formatter | ○ | ● | ◐ | ○ | ◐ | **planned** | — | [E-10](RoadmapEpics.md#e-10-publish-pipeline-stub) |
| Publish queue schedule | ○ | ● | ◐ | ○ | ◐ | **planned** | — | [E-10](RoadmapEpics.md#e-10-publish-pipeline-stub) |
| Buffer-style polish step | ○ | ● | ◐ | ○ | ◐ | **planned** | — | [E-10](RoadmapEpics.md#e-10-publish-pipeline-stub) |
| Static site generator export | ○ | ● | ◐ | ○ | ◐ | **planned** | — | [E-10](RoadmapEpics.md#e-10-publish-pipeline-stub) |
| Read-only web publish | ○ | ● | ◐ | ○ | ◐ | **planned** | — | [E-10](RoadmapEpics.md#e-10-publish-pipeline-stub) |
| WordPress connector | ○ | ● | ◐ | ○ | ◐ | **planned** | — | [E-10](RoadmapEpics.md#e-10-publish-pipeline-stub) |
| Copy as rich text | ○ | ● | ◐ | ○ | ◐ | **planned** | — | [E-10](RoadmapEpics.md#e-10-publish-pipeline-stub) |
| Print layout | ○ | ● | ◐ | ○ | ◐ | **planned** | — | [E-10](RoadmapEpics.md#e-10-publish-pipeline-stub) |
| Metadata for SEO export | ○ | ● | ◐ | ○ | ◐ | **planned** | — | [E-10](RoadmapEpics.md#e-10-publish-pipeline-stub) |
| Publish pipeline stub menu | ○ | ● | ◐ | ○ | ◐ | **planned** | — | [E-10](RoadmapEpics.md#e-10-publish-pipeline-stub) |
| Menubar-only publisher | ○ | ● | ◐ | ○ | ◐ | **planned** | — | [E-10](RoadmapEpics.md#e-10-publish-pipeline-stub) |

## 14. Workbench & navigation

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Three-column workbench | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Sidebar sections | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Document list pane | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Inspector rail | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Multi-tab documents | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Pinned notes | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Split editor panes | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| View Islands pattern | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| All docs journal nav | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Search entry in sidebar | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| WorkbenchState coordinator | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Design tokens theme | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Breadcrumbs in header | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Trash archive section | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Home dashboard | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Onboarding wizard | ◐ | ● | ● | ◐ | ● | **partial** | ✓ | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| No Any-ID signup | — | ● | ● | ● | — | **done** | ✓ | [ADR-0001](adr/0001-local-only-architecture.md) |

## 15. Platform & OS integration

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| macOS native app | ● | ● | ● | ● | ● | **planned** | — | — |
| macOS native app | ● | ● | ● | ● | ● | **done** | ✓ | — |
| macOS sandbox | ● | ● | ● | ● | ● | **planned** | — | — |
| Quick Look preview | ● | ● | ● | ● | ● | **planned** | — | — |
| Spotlight indexer | ● | ● | ● | ● | ● | **planned** | — | — |
| Services menu integration | ● | ● | ● | ● | ● | **planned** | — | — |
| Handoff Continuity | ● | ● | ● | ● | ● | **planned** | — | — |
| Universal Clipboard | ● | ● | ● | ● | ● | **planned** | — | — |
| Native menu bar | ● | ● | ● | ● | ● | **planned** | — | — |
| Keyboard shortcuts HIG | ● | ● | ● | ● | ● | **planned** | — | — |
| VoiceOver support | ● | ● | ● | ● | ● | **planned** | — | — |
| Reduced motion | ● | ● | ● | ● | ● | **planned** | — | — |
| Electron shell | ● | ● | ● | ● | ● | **planned** | — | — |
| Windows client | ● | ● | ● | ● | ● | **planned** | — | — |
| Linux client | ● | ● | ● | ● | ● | **planned** | — | — |

## 16. Mobile & cross-platform

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| iOS app | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 mobile |
| Android app | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 mobile |
| iPad optimized layout | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 mobile |
| Mobile capture | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 mobile |
| Mobile graph view | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 mobile |
| Android app | ● | ● | ● | ○ | ● | **wont** | — | v2-TBD |
| Cross-platform sync | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 mobile |
| Web app PWA | ◐ | ● | ◐ | ○ | ○ | **wont** | — | native-first |

## 17. Tasks journal & workflows

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Todo blocks with due dates | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Task page type | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Agenda query for tasks | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Recurring tasks | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Reminders integration | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Time blocking | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Project hierarchy | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Habit tracker | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| SCHEDULED DEADLINE syntax | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |
| Completed task archive | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [ADR-0002](adr/0002-typed-pages-object-model.md) |

## 18. Media embeds & assets

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Image embed in note | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 media |
| Video embed | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 media |
| Audio recording | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 media |
| Asset vault folder | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 media |
| OCR on images | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 media |
| Web bookmark preview | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 media |
| File attachments | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 media |
| HEIC native formats | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 media |
| Drag-drop into editor | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 media |
| Paste from clipboard rich | ◐ | ● | ● | ◐ | ◐ | **planned** | — | v2 media |

## 19. Settings themes & customization

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Dark light theme | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [design/Tokens](design/Tokens.md) |
| Custom accent color | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Font family size | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Default page type | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| LM Studio URL settings | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | [E-03](RoadmapEpics.md#e-03-lm-studio-rag) |
| Vault location picker | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Auto-lock timeout | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Backup reminders | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Language i18n | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Plugin settings page | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Keyboard shortcut editor | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Reset onboarding | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-08](RoadmapEpics.md#e-08-affine-style-workbench-shell) |

## 20. Performance scale & reliability

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| Vault unlock under 2s M-series | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-04](RoadmapEpics.md#e-04-fsevents-indexer) |
| 10k notes searchable | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-04](RoadmapEpics.md#e-04-fsevents-indexer) |
| Background index no UI block | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-04](RoadmapEpics.md#e-04-fsevents-indexer) |
| Lazy load document bodies | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-04](RoadmapEpics.md#e-04-fsevents-indexer) |
| Memory cap on graph render | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-04](RoadmapEpics.md#e-04-fsevents-indexer) |
| Incremental index on save | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-04](RoadmapEpics.md#e-04-fsevents-indexer) |
| Cold start under 3s | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-04](RoadmapEpics.md#e-04-fsevents-indexer) |
| Battery-friendly indexing | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-04](RoadmapEpics.md#e-04-fsevents-indexer) |
| Crash-safe atomic writes | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-04](RoadmapEpics.md#e-04-fsevents-indexer) |
| Stress test 100+ doc import | ◐ | ● | ● | ◐ | ◐ | **planned** | — | [E-04](RoadmapEpics.md#e-04-fsevents-indexer) |

## 21. OpenWrite differentiators

| Feature | Logseq | AFFiNE | Anytype | Reor | Obsidian | OpenWrite | Pass 1 | OpenWrite link |
|---------|:------:|:------:|:-------:|:----:|:--------:|:---------:|:------:|----------------|
| NDL designed language | ◐ | ● | ● | ◐ | ◐ | **done** | ✓ | [NDL spec](NDL/Specification.md) |
| Past Writes session timeline | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | — |
| rem+ optional import adapter | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | — |
| Beat Anytype capture speed goal | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | — |
| No plugin soup for graph AI | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | — |
| Single-user vault no spaces | ◐ | ● | ● | ◐ | ◐ | **done** | ✓ | [ADR-0001](adr/0001-local-only-architecture.md) |
| Clean-room competitor study | ◐ | ● | ● | ◐ | ◐ | **done** | ✓ | [OpenWriteMasterPlan](OpenWriteMasterPlan.md) |
| Feature parity matrix this doc | ◐ | ● | ● | ◐ | ◐ | **done** | ✓ | — |
| Master plan epics traceability | ◐ | ● | ● | ◐ | ◐ | **done** | ✓ | [RoadmapEpics](RoadmapEpics.md) |
| Buffer publish mental model | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | — |
| massCode snippet import | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | — |
| Screen-memory writing aid | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | — |
| In-memory vault dev mode | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | — |
| OpenWriteAIServices facade | ◐ | ● | ● | ◐ | ◐ | **partial** | ✓ | — |
| Documentation-first delivery | ◐ | ● | ● | ◐ | ◐ | **done** | ✓ | [docs/README](README.md) |

---

## Statistics

| Metric | Count |
|--------|------:|
| **Total feature rows** | 357 |
| OpenWrite **done** | 12 |
| OpenWrite **partial** | 87 |
| OpenWrite **planned** | 222 |
| OpenWrite **wont** | 36 |
| Pass 1 **✓ absorbed** | 96 |
| Pass 1 **◐ partial** | 5 |
| Pass 1 **— missing** | 256 |

## Maintenance

When shipping a feature: update **OpenWrite** status, set **Pass 1** to ✓ when scaffold is complete, check [RoadmapEpics.md](RoadmapEpics.md), and update the matching [features/](features/) doc.

*Owner: OpenWrite core.*
