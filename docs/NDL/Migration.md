# NDL & Vault Migration Guide

**Last updated:** 2026-05-17  
**Related:** [Specification.md](./Specification.md) · [Architecture/DataModel.md](../Architecture/DataModel.md)

This document defines how OpenWrite **bumps versions** for NDL grammar, vault bundle layout, and search indexes—and how operators and developers migrate existing data safely.

---

## Version axes

OpenWrite tracks three independent version numbers:

| Axis | Field | Current | Owned by |
|------|-------|---------|----------|
| **Vault bundle** | `manifest.json` → `version` | `1` (target) | `Core/Vault` |
| **NDL grammar** | `metadata["ndlVersion"]` on document | `"0"` | `NoteDSL` |
| **Index store** | `index/version.json` | `1` (planned) | `Core/Indexing` |

Bump only the axis that changed. A NDL grammar change does not always require a vault `version` bump if the JSON schema for `VaultDocument` is unchanged.

---

## NDL version history

| NDL | Summary | Migration |
|-----|---------|-----------|
| **0** | Initial kinds: paragraph, headings, bullet, quote, code, divider, wikilink, property; 2-space indent; `@key` properties | Baseline |
| **0.1** (planned) | `numbered`, `todo`, `blockref`, `callout`; indent-aware parser; optional `key::` import alias | Auto-upgrade on load |
| **1** (planned) | Multi-level indent validation; embed blocks; stricter errors | Tool-assisted |

---

## NDL 0 → 0.1 (planned)

### Parser changes

- Build `children` from indent stack (fixes flat-only Phase 1 parse).
- Recognize `- [ ]` / `- [x]` → `.todo`.
- Recognize `1. ` lines → `.numbered`.
- Recognize `((uuid))` → `.blockref`.
- Recognize `> [!note]` callout headers.

### Migration algorithm (on document load)

```
for each document in vault:
  if metadata["ndlVersion"] is nil or "0":
    blocks = NDLParserV01.parse(NDLSerializer.serialize(blocks))  // normalize tree
    metadata["ndlVersion"] = "0.1"
    save(document)
```

- **Lossless** for content expressible in both versions.
- Import-only `key::` lines convert to `@key` property blocks once.

### Rollback

- Downgrade not supported: keep backup before bulk migration.
- Export Markdown snapshot before migration (recommended user step).

---

## Vault bundle migrations

### manifest.version = 1 (baseline target)

- Encrypted `.owdoc` per document
- Plaintext `manifest.json`
- `index/` directory optional

### Future manifest.version = 2 (example)

Possible triggers:

- Per-vault `PageTypeRegistry` file
- Consolidated index into single SQLite file
- Changed AEAD algorithm id

**Steps:**

1. Ship `VaultMigrator` that copies bundle to `MyVault.openwrite.migrating`.
2. Transform each document and index artifact.
3. Atomically swap directories on success.
4. Write `manifest.version = 2`.

**User-facing:** App shows “Upgrading vault…” with cancel only before write starts.

---

## Index / embedding migrations

| Change | Action |
|--------|--------|
| New chunker | `rebuildAll(documents:)` |
| Embedding model dimension change | Delete `index/vectors/*`; re-embed all chunks |
| Lexical schema change | Rebuild FTS table |

Store in `index/version.json`:

```json
{
  "indexVersion": 1,
  "embeddingModel": "text-embedding-nomic-embed-text-v1.5",
  "chunker": "heading-v1"
}
```

Mismatch with current `LMStudioConfig` embedding model → prompt user to re-index (non-blocking).

---

## Property schema migrations

`PagePropertyKey` additions are **additive**:

- New keys appear in `PageProperties.schema(for:)` for relevant types.
- Old documents decode missing keys as empty.

**Renaming keys** (breaking):

1. Add new key; migrate values in `VaultMigrator`.
2. Deprecate old key for one release.
3. Remove old key support.

Document in ADR when renaming.

---

## PageType registry

Adding built-in `PageType` cases:

- Codable decode unknown raw values → fallback to `.note` OR custom registry entry.
- `PageTypeRegistry` in manifest lists enabled types for UI.

Custom types (v2+): string ids in `customTypeIDs`; templates stored separately.

---

## Compatibility matrix

| Reader \ Writer | NDL 0 | NDL 0.1 | manifest v1 | manifest v2 |
|-----------------|-------|---------|-------------|-------------|
| App 1.0 (Phase 1) | R/W | R partial | R/W stub | — |
| App 1.1 (target) | R/W + migrate | R/W | R/W | migrate |

---

## Developer checklist (version bump PR)

- [ ] Update [Specification.md](./Specification.md) version section
- [ ] Add row to this file’s history tables
- [ ] Implement migrator or load-time upgrade
- [ ] Golden tests: before/after fixture documents
- [ ] Update [docs/README.md](../README.md) if user-visible
- [ ] ADR if breaking or irreversible

---

## User backup policy

Before any automatic migration:

- Recommend Time Machine / manual copy of `.openwrite` bundle.
- App MAY create `manifest.json.bak` and `documents/*.owdoc.bak` on first launch after upgrade (v1.1 product decision).

---

## Related documents

- [Specification.md](./Specification.md)
- [Architecture/DataModel.md](../Architecture/DataModel.md)
- [Contributing/DocumentationStandards.md](../Contributing/DocumentationStandards.md)
- [VersioningFramework.md](../VersioningFramework.md) *(planned)*
