# Database presets and schemas

**Last updated:** 2026-05-17  
**Status:** Spec (v2 — `OWDatabase`)  
**Related:** [ProductDirection.md](../ProductDirection.md) · [OpenWriteMasterPlan.md](../OpenWriteMasterPlan.md) · [TypedPagesAndStructures.md](./TypedPagesAndStructures.md) · [Architecture/DataModel.md](../Architecture/DataModel.md) · [ADR 0002](../adr/0002-typed-pages-object-model.md)

OpenWrite’s **ultimate database** vision: one vault, many **user-defined databases** (`OWDatabase`). Each database has a field schema, saved views (filter/sort/columns), and **rows** backed by normal `VaultDocument` pages (NDL body + typed properties). Built-in **presets** ship common schemas; users duplicate or extend them.

**massCode role:** massCode proved users want a **structured snippet store**. OpenWrite does not stop at snippets — the same `OWDatabase` abstraction holds books, tasks, reading lists, and custom tables.

---

## OWDatabase (conceptual model)

| Piece | Storage (target) | Notes |
|-------|------------------|-------|
| Database definition | `databases/{uuid}.owdb.json` in vault (plaintext metadata) or manifest section | Name, field defs, default `pageType` |
| View | Inside definition: `views[]` | Filter predicate, sort, visible columns, layout (`table` \| `board` \| `calendar`) |
| Row | `documents/{uuid}.owdoc` | `metadata["databaseId"]`, `metadata["databaseRowId"]` optional; properties hold column values |
| Body | `rootBlocks` (NDL) | Long text, code, chapter prose — not duplicated in every column |

```json
{
  "id": "a1b2c3d4-e5f6-7890-abcd-ef1234567890",
  "name": "Snippet Store",
  "presetId": "snippet_store",
  "primaryPageType": "snippet",
  "fields": [
    { "key": "title", "type": "string", "required": true },
    { "key": "language", "type": "enum", "options": ["swift", "typescript", "shell", "other"] },
    { "key": "tags", "type": "tags" },
    { "key": "sourceUrl", "type": "url" }
  ],
  "views": [
    {
      "id": "all",
      "name": "All snippets",
      "layout": "table",
      "columns": ["title", "language", "tags", "updatedAt"],
      "filter": null,
      "sort": [{ "key": "updatedAt", "desc": true }]
    }
  ]
}
```

Row documents reference the database:

```json
{
  "id": "550e8400-e29b-41d4-a716-446655440000",
  "title": "Keychain unlock helper",
  "pageType": "snippet",
  "properties": {
    "title": "Keychain unlock helper",
    "language": "swift",
    "tags": ["vault", "crypto"],
    "sourceUrl": "https://example.com/docs"
  },
  "metadata": {
    "databaseId": "a1b2c3d4-e5f6-7890-abcd-ef1234567890"
  },
  "rootBlocks": [
    { "kind": "code", "text": "func unlockVault() async throws { ... }", "attributes": { "language": "swift" } }
  ]
}
```

---

## Built-in presets

| Preset ID | Display name | Primary `PageType` | massCode / competitor lineage | Default view |
|-----------|--------------|-------------------|------------------------------|--------------|
| `snippet_store` | Snippet Store | `snippet` (new) or `note` until enum lands | **massCode** — folders, tags, language | Table: title, language, tags |
| `task_board` | Task board | `task` | Anytype/AFFiNE task DB (behavior only) | Board: `status` columns |
| `reference_library` | Reference library | `reference` | Zotero-lite / Reor sources | Table: title, author, url |
| `reading_list` | Reading list | `reference` | Goodreads-style queue | Table: status, title, author |
| `book_manuscript` | Book | `book` | Structure template + row per chapter optional | Table: chapter, word count |
| `journal_log` | Journal | `journal` | Daily notes apps | Calendar: `date` (v2 layout) |
| `project_tracker` | Projects | `project` | PM-lite | Table: status, due, owner |
| `contact_rolodex` | Contacts | `note` + custom fields | CRM-lite | Table: name, email, lastContact |
| `recipe_box` | Recipes | `note` | Personal wiki | Table: cuisine, time, rating |
| `inbox_capture` | Inbox | `note` | Reor / fast capture | Table: createdAt, processed |

Users can **duplicate preset → custom database** and add/remove fields without leaving the vault.

---

## Schema examples (per preset)

Field `type` vocabulary (v1 target): `string`, `text`, `number`, `boolean`, `date`, `datetime`, `url`, `email`, `enum`, `tags`, `relation` (wikilink to doc UUID, v2).

### Snippet Store (`snippet_store`)

massCode parity target. Code body lives in NDL `code` block; metadata drives the table.

```json
{
  "presetId": "snippet_store",
  "fields": [
    { "key": "title", "type": "string", "required": true },
    { "key": "language", "type": "enum", "options": ["swift", "typescript", "javascript", "python", "shell", "sql", "other"] },
    { "key": "tags", "type": "tags" },
    { "key": "sourceUrl", "type": "url" },
    { "key": "favorite", "type": "boolean", "default": false }
  ],
  "views": [
    {
      "id": "by_language",
      "name": "By language",
      "layout": "table",
      "groupBy": "language",
      "columns": ["title", "tags", "updatedAt"]
    }
  ]
}
```

**massCode import mapping (illustrative):**

| massCode field | OWDatabase / `PageProperties` |
|----------------|------------------------------|
| `name` | `title` |
| `content` | NDL `code` or `paragraph` block |
| `language` | `language` |
| `tags[]` | `tags` |
| `folder` | view filter or `tags` |

---

### Task board (`task_board`)

Aligns with existing `PageType.task` schema.

```json
{
  "presetId": "task_board",
  "fields": [
    { "key": "title", "type": "string", "required": true },
    { "key": "status", "type": "enum", "options": ["todo", "doing", "done", "blocked"] },
    { "key": "dueDate", "type": "date" },
    { "key": "priority", "type": "enum", "options": ["low", "medium", "high"] },
    { "key": "project", "type": "relation" }
  ],
  "views": [
    {
      "id": "kanban",
      "name": "Board",
      "layout": "board",
      "groupBy": "status",
      "columns": ["title", "dueDate", "priority"]
    }
  ]
}
```

---

### Reference library (`reference_library`)

```json
{
  "presetId": "reference_library",
  "fields": [
    { "key": "title", "type": "string", "required": true },
    { "key": "author", "type": "string" },
    { "key": "url", "type": "url" },
    { "key": "publishedYear", "type": "number" },
    { "key": "tags", "type": "tags" },
    { "key": "citeKey", "type": "string" }
  ],
  "views": [
    {
      "id": "all_refs",
      "name": "All references",
      "layout": "table",
      "sort": [{ "key": "title", "desc": false }]
    }
  ]
}
```

---

### Reading list (`reading_list`)

```json
{
  "presetId": "reading_list",
  "fields": [
    { "key": "title", "type": "string", "required": true },
    { "key": "author", "type": "string" },
    { "key": "status", "type": "enum", "options": ["want", "reading", "finished", "abandoned"] },
    { "key": "rating", "type": "number" },
    { "key": "startedAt", "type": "date" },
    { "key": "finishedAt", "type": "date" }
  ]
}
```

---

### Book manuscript (`book_manuscript`)

Uses [Structure template: Book](./TypedPagesAndStructures.md). Optional **one row per chapter** when users want a database lens over child pages.

```json
{
  "presetId": "book_manuscript",
  "fields": [
    { "key": "title", "type": "string", "required": true },
    { "key": "chapterNumber", "type": "number" },
    { "key": "status", "type": "enum", "options": ["outline", "draft", "revise", "final"] },
    { "key": "wordCount", "type": "number" },
    { "key": "parentBookId", "type": "relation" }
  ],
  "views": [
    {
      "id": "chapters",
      "name": "Chapters",
      "layout": "table",
      "sort": [{ "key": "chapterNumber", "desc": false }],
      "filter": { "parentBookId": { "notNull": true } }
    }
  ]
}
```

Root book page uses `StructureTemplate.book`; chapter rows link via `parentBookId` + wikilinks.

---

### Journal log (`journal_log`)

```json
{
  "presetId": "journal_log",
  "fields": [
    { "key": "title", "type": "string" },
    { "key": "date", "type": "date", "required": true },
    { "key": "mood", "type": "enum", "options": ["great", "good", "neutral", "low"] },
    { "key": "tags", "type": "tags" }
  ],
  "views": [
    {
      "id": "calendar",
      "name": "Calendar",
      "layout": "calendar",
      "dateField": "date"
    }
  ]
}
```

---

### Project tracker (`project_tracker`)

```json
{
  "presetId": "project_tracker",
  "fields": [
    { "key": "title", "type": "string", "required": true },
    { "key": "status", "type": "enum", "options": ["idea", "active", "on_hold", "shipped"] },
    { "key": "targetDate", "type": "date" },
    { "key": "owner", "type": "string" },
    { "key": "tags", "type": "tags" }
  ]
}
```

---

### Contact rolodex (`contact_rolodex`)

```json
{
  "presetId": "contact_rolodex",
  "fields": [
    { "key": "name", "type": "string", "required": true },
    { "key": "email", "type": "email" },
    { "key": "organization", "type": "string" },
    { "key": "lastContact", "type": "date" },
    { "key": "tags", "type": "tags" }
  ]
}
```

---

### Recipe box (`recipe_box`)

```json
{
  "presetId": "recipe_box",
  "fields": [
    { "key": "title", "type": "string", "required": true },
    { "key": "cuisine", "type": "string" },
    { "key": "prepMinutes", "type": "number" },
    { "key": "servings", "type": "number" },
    { "key": "rating", "type": "number" },
    { "key": "tags", "type": "tags" }
  ]
}
```

Body: NDL bullets for ingredients and steps.

---

### Inbox capture (`inbox_capture`)

Fast capture queue before triage into other databases.

```json
{
  "presetId": "inbox_capture",
  "fields": [
    { "key": "title", "type": "string" },
    { "key": "capturedAt", "type": "datetime", "required": true },
    { "key": "processed", "type": "boolean", "default": false },
    { "key": "targetDatabase", "type": "string" }
  ],
  "views": [
    {
      "id": "unprocessed",
      "name": "Inbox",
      "filter": { "processed": false },
      "sort": [{ "key": "capturedAt", "desc": true }]
    }
  ]
}
```

---

## UI placement (workbench)

| Surface | Behavior |
|---------|----------|
| Sidebar | **Databases** section lists presets + user databases |
| Center | Table/board view **or** open row → editor (writing-first: double-click opens NDL) |
| Inspector | Row properties + backlinks + AI (unchanged posture) |

Default: opening a database shows the **table lens**; selecting a row opens the **editor** in the center column (same as today’s page flow). massCode-style “copy snippet” is a row action, not a separate app mode.

---

## Phasing

| Phase | Deliverable |
|-------|-------------|
| **Now (v1)** | Typed `PageType` + properties; structure templates; no `OWDatabase` UI |
| **v2a** | `OWDatabase` model on disk; Snippet Store + Task board table views |
| **v2b** | Custom fields; duplicate preset; massCode JSON import |
| **v2c** | Board/calendar layouts; `relation` column type |

---

## Acceptance criteria (v2a)

- [ ] User creates vault with **Snippet Store** preset; new row creates encrypted `.owdoc` with schema properties.
- [ ] Table view filters by tag and language (massCode parity).
- [ ] Row opens in NDL editor; code block round-trips.
- [ ] User adds second database (e.g. Reading list) in same vault without new app install.
- [ ] massCode JSON import populates Snippet Store rows with AGPL attribution in import log.

---

## Non-goals

- Anytype ASAL schemas, relation types, or sync mesh
- SQL queries across vaults or external Postgres
- Replacing `PageType` registry — presets **compose with** typed pages, not replace them
- Shipping massCode Electron binary or npm runtime

---

*Owner: OpenWrite core. Update when `OWDatabase` Swift types land or preset IDs change.*
