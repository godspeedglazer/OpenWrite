# Import & export

**Epic:** [E-07](../RoadmapEpics.md#e-07-import-markdown--obsidian) · Export also [E-10](../RoadmapEpics.md#e-10-publish-pipeline-stub) (publish views)  
**ADR:** [ADR-0001](../adr/0001-local-only-architecture.md) (local truth = NDL in vault)  
**Status:** **Partial** (Phase 1 pass: `MarkdownImporter` stub + `NDLParser`; no Obsidian folder pipeline)

---

## Summary

OpenWrite’s **canonical format is NDL inside encrypted `.owdoc` files**, not Markdown on disk. Import and export are **bridges**: bring legacy knowledge in without becoming a “Markdown vault app,” and ship writing out to interoperable formats and publish templates.

**Import priority:** Obsidian folder + single `.md` files (P2 epic, high user demand from Reor study).  
**Export priority:** Lossless-enough Markdown + plain text in v1; PDF and Buffer-style publish queues in v2 (E-10).

---

## Import pipelines

### Markdown file → NDL

```
.md file → MarkdownImporter → NDLParser.parse(lines) → VaultDocument.rootBlocks
```

| Input element | NDL mapping |
|---------------|-------------|
| `# Heading` | `heading1` … `heading3` |
| `- item` | `bullet` with optional indent → children (E-02 tree) |
| `> quote` | `quote` |
| `[[wikilink]]` | `wikilink` block |
| YAML frontmatter | `PageProperties` + `PageType` inference |

**Phase 1 pass:** `Import/MarkdownImporter.swift` calls parser; no batch UI.

### Obsidian vault folder (E-07)

| Step | Behavior |
|------|----------|
| Scan | User selects folder; enumerate `.md` recursively |
| Map paths | Relative path → suggested title; respect `.obsidian/` ignore |
| Attachments | Copy `![[image]]` as `asset` blocks (v1.1) or skip with report |
| Wikilinks | Preserve `[[Note]]`; rebuild `BacklinkIndex` after import |
| Write | Create encrypted `.owdoc` per note via E-01 |

**Not imported in v1:** Obsidian plugins, `.canvas` files, Dataview queries, community themes.

### Other sources (planned / optional)

| Source | Status | Notes |
|--------|--------|-------|
| Logseq export | planned | Markdown + properties only |
| Reor vault | planned | Folder of `.md` similar path |
| Anytype | **wont** | ASAL — no code contact |
| massCode | planned P2 | Snippet JSON optional |
| rem+ SQLite | partial | [PastWrites.md](./PastWrites.md) — sessions only, not full notes |

---

## Export pipelines

### NDL → Markdown (v1)

| Block kind | Markdown output |
|------------|-----------------|
| `heading1` | `# text` |
| `bullet` | `- text` + indent children |
| `wikilink` | `[[title]]` |
| `code` | fenced code block |
| `property` | YAML frontmatter aggregate |

Round-trip is **best-effort**, not guaranteed identical to source file (by design — NDL is master).

### Plain text & PDF

| Format | Epic | Status |
|--------|------|--------|
| Plain text | E-07 | planned — strip block markup |
| PDF | E-10 | planned v2 — `Print` / `PDFKit` |
| HTML | E-10 | planned v2 — publish templates |

---

## Publish pipeline (E-10 stub)

Buffer-inspired **draft → polish → publish view** without shipping Buffer binary:

| Stage | Output |
|-------|--------|
| Draft | NDL in vault |
| Polish | AI assist (E-03) optional |
| Publish view | Thread / newsletter / blog MD templates |

v1 stub: menu item + empty `ExportPipeline` protocol; no queue scheduler.

---

## Data integrity rules

1. **Import never writes plaintext `.owdoc` to disk** — seal through `EncryptionService` (E-01).
2. **UUID assignment** — new `VaultDocument.id` per imported file; optional map file for re-import idempotency.
3. **Conflict policy** — duplicate title → suffix `(imported)` or user prompt.
4. **Audit log** — `manifest.imports[]` records source path + timestamp (optional v1.1).

---

## UI flows

| Flow | Entry |
|------|-------|
| Import folder | File → Import Obsidian Vault… |
| Import file | Drag `.md` onto dock icon / editor |
| Export note | Share → Export Markdown… |
| Export vault | Settings → Export all as Markdown folder (plaintext export warning) |

---

## Acceptance criteria

### E-07 (import)

- [ ] Select Obsidian vault folder; ≥95% notes become valid `VaultDocument`
- [ ] Wikilinks resolve where target file exists
- [ ] Import report lists skipped files + reasons
- [ ] Imported vault survives lock/unlock round-trip

### Export (v1 subset)

- [ ] Single note exports to `.md` matching table above
- [ ] Export does not leave decrypted copy without user acknowledgement

---

## Pass 1 absorption

| Absorbed | Missing |
|----------|---------|
| `MarkdownImporter` + `NDLParser` | Folder scanner, UI, attachment copy |
| Import hooks in architecture docs | Obsidian `.obsidian` config |
| Export mentioned in master plan | `NDLSerializer` export path tests |
| — | PDF, publish templates (E-10) |

---

## Related

- [FeatureParityMatrix.md § Import & export](../FeatureParityMatrix.md#12-import--export)
- [VaultEncryption.md](./VaultEncryption.md)
- [NDL/Specification.md](../NDL/Specification.md)
- [NDL/Migration.md](../NDL/Migration.md)
