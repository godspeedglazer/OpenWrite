# Typed pages and structure templates

**Last updated:** 2026-05-17  
**Status:** Implemented (Phase 1, in-memory vault)  
**Related:** [ADR 0002](../adr/0002-typed-pages-object-model.md) · [Architecture/DataModel.md](../Architecture/DataModel.md)

OpenWrite provides **typed pages** (object kinds with property schemas) and **structure templates** (heading scaffolds inspired by Anytype-style convenience, implemented clean-room and local-only).

---

## Page types

Built-in `PageType` values:

| Type | Use |
|------|-----|
| `note` | Default free-form writing |
| `task` | Action items with status, due date, priority |
| `reference` | Sources, URLs, citations |
| `journal` | Dated reflections |
| `project` | Outcomes, milestones, resources |
| `book` | Long-form manuscript with chapter headings |
| `document` | Structured article/report with H1–H3 outline |
| `wiki_site` | Site home plus linked child pages |
| `collection` | Folder-like grouping with item links |

**Quick picker** (sidebar “New typed page”) shows note, task, reference, journal, and project only. Structure-first types are created via **structure templates** below.

Each type has:

- A **property schema** (`PageProperties.schema(for:)`)
- Default **starter layout** (`TypeTemplate.template(for:)`)
- Sidebar icon and editor badge color

---

## Structure templates

`StructureTemplate` presets map 1:1 to structure page types:

| Template | Page type | Root scaffold | Child pages |
|----------|-----------|---------------|-------------|
| Book | `book` | H1 title, H2 chapters | None |
| Document | `document` | H1 + intro/body/conclusion with H2/H3 | None |
| Wiki Site | `wiki_site` | H1 home, site map, getting started + wikilinks | About, Guide, Reference |
| Collection | `collection` | H1 index, items section + wikilinks | Item 1–3 (notes) |

### Heading outline

`StructureTemplate.headingOutline(rootTitle:)` returns an ordered list of `OutlineHeading` (levels 1–3). `StructureTemplate.blocks(from:)` turns that into `NoteBlock` headings and optional placeholder paragraphs — the **site headings outline** for structured docs.

### Creation flow

1. User opens **New typed page** sheet.
2. **Structure template** section (`StructureTemplatePicker`) — title field + Book / Document / Wiki Site / Collection.
3. **Quick page type** section (`TypePickerView`) — classic five types.
4. `VaultStore.createFromStructure(_:title:)`:
   - Builds root via `TypeTemplate.template(for: structure, title:)`
   - Sets `metadata["structureTemplate"]`
   - For wiki/collection, creates child documents with `metadata["parentDocumentID"]` and stores comma-separated `childDocumentIDs` on the root

Child pages are ordinary vault documents (not a separate on-disk format in Phase 1).

---

## Code map

| File | Role |
|------|------|
| `Models/PageType.swift` | Enum + registry |
| `Models/PageProperties.swift` | Schemas and defaults |
| `Models/StructureTemplate.swift` | Outlines, child specs, block generation |
| `Models/TypeTemplate.swift` | Layouts; delegates structure types to `StructureTemplate` |
| `Core/Vault/VaultStore.swift` | `createDocument`, `createFromStructure` |
| `UI/Types/StructureTemplatePicker.swift` | Create UI for structures |
| `UI/Types/TypePickerView.swift` | Quick types + type switch |

---

## Acceptance criteria

- [x] Four structure presets with H1/H2/H3 scaffolds on the root page
- [x] Wiki site and collection create linked child pages in the vault
- [x] Structure templates integrate with `PageType` and `TypeTemplate`
- [x] New-page sheet offers structure picker before quick types
- [ ] Persisted vault bundle writes `structureTemplate` metadata (disk I/O deferred)
- [ ] Sidebar grouping by parent collection (UI deferred)

---

## Non-goals (v1)

- Anytype sync, relations, or set/database views
- Automatic outline regeneration after edit
- Custom user-defined structure templates (registry extension later)
