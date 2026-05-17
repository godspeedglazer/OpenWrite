# Universal databases

**Last updated:** 2026-05-17  
**Status:** *Partial* (in-memory vault; Codable snapshot for future `.openwrite` bundle)  
**Related:** [VaultEncryption.md](./VaultEncryption.md) · [Workbench.md](./Workbench.md) · [Architecture/DataModel.md](../Architecture/DataModel.md)

OpenWrite ships **universal local databases**: user-defined schemas and row collections for *any* structured content — code snippets, bookmarks, reading lists, inventory, or a blank table you extend later. This is **not** a snippets-only lab; notes remain `VaultDocument` + NDL, while databases are a parallel model optimized for tabular browse and edit.

**Inspiration only:** Public [massCode](https://github.com/massCodeIO/massCode) concepts (folders of snippets, fielded storage). Implementation is clean-room Swift; no AGPL code is linked.

---

## Design stance

| Layer | Responsibility |
|-------|----------------|
| **`OWDatabase`** | Schema: name, fields (`OWFieldKind`: text, code, tags, date, url, number), icon, theme tint |
| **`OWDatabaseEntry`** | One row; cell values keyed by field id |
| **`VaultStore`** | In-memory registry + CRUD; `VaultSnapshot` Codable for bundle export |
| **Workbench UI** | Sidebar **Databases** (below Objects), table center, create sheet |

Databases coexist with typed pages and the link graph. They do not replace NDL notes; users pick the right container per workflow.

---

## Presets

| Preset | Default fields | Typical use |
|--------|----------------|-------------|
| `codeSnippets` | Title, Language, Tags, Code | Reusable code blocks |
| `bookmarks` | Name, URL, Tags, Notes | Saved links |
| `readingList` | Title, Author, URL, Status, Tags, Notes | Books and articles to read |
| `custom` | Title (text) | Blank schema; add columns later (UI stub) |

Presets seed schema and tint; the user may rename the database at creation time.

---

## UI surfaces

1. **Sidebar → Databases** — list databases, **+** opens create sheet.  
2. **`CreateDatabaseSheet`** — pick preset, optional name, schema preview.  
3. **`DatabaseTableView`** — column headers from schema, row tap opens entry editor sheet.  
4. **Center workbench `.database(OWDatabase)`** — table view for the active database (alongside Editor and Graph tabs).

---

## Persistence (Phase 1)

- `VaultStore.databases` and `VaultStore.databaseEntries` live in memory with documents.  
- `VaultSnapshot` encodes `documents`, `databases`, `databaseEntries`, and `version` for a future encrypted `.openwrite` manifest.  
- Per-row disk files (e.g. `databases/{db-id}/entries/{entry-id}.json`) are deferred until vault-on-disk lands in [VaultEncryption.md](./VaultEncryption.md).

---

## Acceptance criteria (shipped in this slice)

- [x] Create database from preset or custom blank schema  
- [x] List databases in sidebar below Objects  
- [x] Add / edit / delete entries in a table view  
- [x] Codable models + `VaultSnapshot` on `VaultStore`  
- [ ] Schema editor (add/reorder/remove fields after creation)  
- [ ] Search / filter rows within a database  
- [ ] Link database rows to `VaultDocument` (wikilink or relation)  
- [ ] Import/export CSV or massCode JSON (clean-room adapters)

---

## Code map

| File | Role |
|------|------|
| `Models/OWDatabase.swift` | Schema, presets, theme tint |
| `Models/OWDatabaseEntry.swift` | Row values |
| `Core/Vault/VaultSnapshot.swift` | Bundle DTO |
| `Core/Vault/VaultStore.swift` | CRUD + snapshot encode |
| `UI/Database/DatabaseListView.swift` | Sidebar section |
| `UI/Database/DatabaseTableView.swift` | Table + entry sheet |
| `UI/Database/CreateDatabaseSheet.swift` | Preset picker |
