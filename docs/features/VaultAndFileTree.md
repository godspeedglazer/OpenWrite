# Vault navigation & file tree

**Last updated:** 2026-05-17  
**Status:** Spec (Phase 1 in-memory vault; disk layout per [VaultEncryption.md](./VaultEncryption.md))  
**Related:** [Workbench.md](./Workbench.md) · [TypedPagesAndStructures.md](./TypedPagesAndStructures.md) · [GraphView.md](./GraphView.md) · [ImportExport.md](./ImportExport.md) · [E-06](../RoadmapEpics.md#e-06-backlinks-graph) · [E-07](../RoadmapEpics.md#e-07-import-markdown--obsidian) · [E-08](../RoadmapEpics.md#e-08-affine-style-workbench-shell)

OpenWrite borrows the **mental model** of an Obsidian-style vault (one owned corpus, wikilinks, optional folder paths) without shipping Obsidian’s plugin API, Markdown-on-disk source of truth, or closed-source runtime. This document defines how **navigation** works: sidebar tree, flat lists, typed objects, and how that ties to NDL, structure templates, and the link graph.

**Inspiration only:** Public Obsidian docs describe `Vault`, folder layout, and `[[wikilink]]` behavior. Implementation is clean-room Swift against `.openwrite` + NDL.

---

## Design stance: hybrid navigation

Competitors each bias one axis:

| Model | Primary navigation | Strength | Weakness for OpenWrite |
|-------|-------------------|----------|-------------------------|
| **Folder tree** (Obsidian, classic PKM) | Filesystem paths | Familiar, backup-friendly | Folders ≠ links; block structure is an afterthought |
| **Flat list + search** (Reor, early capture) | Title list + semantic search | Fast scan | Weak hierarchy for books, wikis, projects |
| **Typed object graph** (Anytype) | Types, relations, sets | Rich structure | Onboarding friction, ASAL boundary, overkill for daily writing |

**OpenWrite hybrid:** All documents live in one **encrypted vault** (`VaultDocument` registry in `manifest.json`). The UI exposes **three complementary views** over the same data—never three sources of truth.

```mermaid
flowchart TB
  subgraph store [Single source of truth]
    VD[VaultDocument registry]
    NDL[NDL block trees in .owdoc]
    META[PageType + PageProperties + metadata]
  end

  subgraph views [Workbench navigation views]
    TREE[Folder tree optional virtual paths]
    LIST[Flat / filtered lists]
    TYPE[Typed sections and smart collections]
  end

  subgraph graph [Link layer E-06]
    WIKI[[wikilink]] blocks
    BL[BacklinkIndex]
    GV[GraphView read-only]
  end

  VD --> TREE
  VD --> LIST
  VD --> TYPE
  NDL --> WIKI --> BL --> GV
```

### 1. Folder tree (virtual paths)

- **Not** the on-disk truth: ciphertext lives at `documents/{uuid}.owdoc` (see [Architecture/DataModel.md](../Architecture/DataModel.md)).
- **Optional** `metadata["folderPath"]`** or import-derived path (e.g. `Projects/OpenWrite/Spec`) drives a **collapsible tree** in the workbench sidebar (E-08).
- Folders are **labels for grouping**, not containers that own block content. Moving a note in the tree updates metadata only.
- **Import (E-07):** Obsidian relative paths seed `folderPath`; user may flatten or reorganize without breaking wikilinks (links key off title/UUID, not path).

### 2. Flat list & smart collections

- **All notes** — default `SidebarSection.allNotes`: sort by `updatedAt`, title, or type.
- **Inbox / Journal** — product sections (E-09 capture, dated `journal` type) are **filtered lists**, not separate stores.
- **Smart collections (v1.1)** — AFFiNE-inspired saved predicates over `PageType`, tags, and dates (clean-room `CollectionRuleEngine`); appear alongside static sections in [Workbench.md](./Workbench.md).

### 3. Typed objects & structure templates

- **`PageType`** (`note`, `task`, `reference`, `journal`, `project`, plus structure types) provides **schema + inspector** without a global object-relation graph ([ADR 0002](../adr/0002-typed-pages-object-model.md)).
- **`StructureTemplate`** (book, document, wiki site, collection) scaffolds **heading outlines** and, for wiki/collection, **child `VaultDocument` rows** linked via `metadata["parentDocumentID"]` / `childDocumentIDs` ([TypedPagesAndStructures.md](./TypedPagesAndStructures.md)).
- Sidebar **Types** section groups by `pageType`; structure roots may also appear under a **Structures** or parent collection node when `structureTemplate` metadata is set.

**Rule:** Pick tree *or* type filter for muscle memory; both read the same `VaultStore` document set.

---

## Wikilinks, backlinks, and graph (E-06)

Linking is **content-native**, not folder-native—aligned with Obsidian/Reor wiki behavior, implemented on NDL.

| Mechanism | Storage | Navigation effect |
|-----------|---------|-------------------|
| `[[Title]]` / `[[Title\|uuid]]` | `NoteBlock.Kind.wikilink` in NDL | Open target doc; autocomplete from vault titles |
| Block reference `((uuid))` | `blockref` (v0.1+) | Jump to block; optional graph edge later |
| **Backlink index** | `BacklinkIndex` — `target → [sources]` | Inspector + sidebar incoming links |
| **Graph view** | Derived from wikilinks | Read-only force/hierarchical layout; see [GraphView.md](./GraphView.md) |

**Planned in E-06 (not shipped in Phase 1 pass):**

- Incremental index update on save
- Unresolved link stubs (title-only ghost nodes)
- Local neighborhood vs global graph modes
- Inspector **Backlinks** tab next to Related (semantic, E-03)

Folders do **not** imply links. Two notes in the same folder are unrelated unless NDL links them.

---

## How this differs from Anytype’s object graph

| Dimension | Anytype | OpenWrite hybrid |
|-----------|---------|------------------|
| **Unit of storage** | Object + type + relation edges in heart middleware | `VaultDocument` + NDL tree in encrypted `.owdoc` |
| **Navigation default** | Graph, sets, types, linked objects | Writer-first: list/tree + editor; graph is optional lens |
| **Relations** | First-class typed relations between objects | **Deferred** — wikilinks + light `PageProperties` only in v1 |
| **Sets / databases** | Query objects into views | **Smart collections** over metadata (predicates), not SQL-on-objects |
| **Identity** | Any-ID, spaces, sync | Single-user vault UUID; no account |
| **Legal** | ASAL — no code contact | Independent schema (`VaultDocument`, `NoteBlock`) |

OpenWrite **does not** replicate Anytype’s object graph, relation types, or set algebra. Users who need “this task *relates to* this project” use wikilinks, shared tags, and matching `PageType` filters until v2+ **typed relation edges** are explicitly scoped (still not an Anytype clone).

---

## Integration with NDL, typed pages, and structure templates

### NDL as canonical body

- Navigation opens a **`VaultDocument`**; the editor renders **`rootBlocks`** ([NDL/Specification.md](../NDL/Specification.md)).
- Wikilinks are **blocks**, not separate link files—export to Markdown writes `[[title]]` for interchange ([ImportExport.md](./ImportExport.md)).
- Outline sidebar (planned E-02) walks heading blocks inside the active doc; it is not a second file tree.

### Typed pages

- `PageType` drives **icon, badge, property schema**, and default list filters.
- Properties live in **`PageProperties`** (JSON canonical; optional NDL `property` lines for display/export).
- Creating via **quick types** vs **structure templates** both call `VaultStore.createDocument` / `createFromStructure`—same registry, different starter blocks.

### Structure templates

| Template | Navigation UX |
|----------|----------------|
| **Book / Document** | Single doc; tree shows one leaf under optional folder |
| **Wiki site** | Root + child pages; tree shows **expandable parent** from `childDocumentIDs` |
| **Collection** | Root index with wikilinks to child notes; sidebar may nest children under parent |

Child pages are normal documents; the tree can mirror **parent metadata** before explicit folder paths exist.

### Journal & capture

- **Journal** type + dated properties → **Journal** sidebar section (filtered list, not a separate vault).
- **Inbox** (E-09) → append to designated inbox doc or today’s journal; appears in flat list, not a folder requirement.

---

## Workbench placement (E-08)

| UI region | Navigation role |
|-----------|-----------------|
| **Sidebar — sections** | All notes, Inbox, Journal, Types, Graph, Search |
| **Sidebar — tree** | Optional folder hierarchy + structure parent/child nesting |
| **Document list** | Section filter + sort; selection → editor |
| **Editor** | NDL editing, wikilink click, outline |
| **Inspector** | Properties (typed pages), Backlinks (E-06), Related (E-03) |
| **Graph island** | Full-vault link view ([GraphView.md](./GraphView.md)) |

Keyboard targets (planned): focus sidebar tree, focus list, toggle graph island — see [Workbench.md](./Workbench.md).

---

## On-disk vs displayed tree

```
MyVault.openwrite/
  manifest.json          # documentIds[] — flat registry
  documents/
    {uuid}.owdoc         # no folder segments in filename
```

Displayed folders are **derived view state** (metadata + import paths), exportable as Markdown folder layout on **export only** (user warned: export is plaintext).

---

## Import note (Obsidian folders)

OpenWrite’s importer (E-07) maps Obsidian folder layout → `folderPath` metadata and preserves `[[wikilinks]]` into NDL. For **reference only** when studying Markdown → block conversion edge cases in the vendored AFFiNE tree (not linked into the app):

`AFFiNE-canary/blocksuite/affine/widgets/linked-doc/src/transformers/obsidian.ts`

Shipped import remains **clean-room Swift** (`Core/Import/ObsidianImporter.swift`, `MarkdownImporter`) per [ImportExport.md](./ImportExport.md). Do not embed BlockSuite or copy AGPL/EE code into the product binary.

---

## Acceptance criteria (navigation)

- [ ] Sidebar shows flat all-notes list with sort by updated/title/type
- [ ] Optional folder tree reflects `folderPath` / import path without changing `.owdoc` filenames
- [ ] Types section filters by `PageType`; structure parents show linked children
- [ ] Wikilink click opens correct document; broken links show unresolved state (E-06)
- [ ] Tree, list, and graph selections stay in sync for active document
- [ ] Lock/unlock vault preserves metadata paths and parent/child IDs

---

## Non-goals (v1)

- Obsidian plugin API or theme compatibility
- Markdown files as live vault source (NDL in `.owdoc` is canonical)
- Anytype-style relation graph or object sets
- Real-time collaborative folder sync
- Datalog / query language over the graph ([GraphView.md](./GraphView.md))

---

## Related

- [OpenWriteMasterPlan.md § Logseq / Obsidian](../OpenWriteMasterPlan.md#logseq--obsidian-outliner--files)
- [FeatureParityMatrix.md § Workbench & navigation](../FeatureParityMatrix.md#14-workbench--navigation)
- [Architecture/DataModel.md](../Architecture/DataModel.md)
