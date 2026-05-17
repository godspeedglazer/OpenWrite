# OpenWrite Versioning Framework

**Version:** 1.0  
**Last updated:** 2026-05-17  
**Related:** [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md) · [RoadmapEpics.md](./RoadmapEpics.md) · [ProductPhilosophy.md](./ProductPhilosophy.md) · [adr/](./adr/)

---

## Purpose

OpenWrite ships several **independently versioned artifacts**: the macOS app, the Note Design Language (NDL) schema, the on-disk vault bundle format, and architectural decision records (ADRs). This document defines how those version numbers move, how migrations run, and how teams avoid silent data loss when any layer changes.

The framework supports the [master plan](./OpenWriteMasterPlan.md) goal of **lossless NDL round-trip** inside encrypted `.owdoc` blobs and the [RoadmapEpics](./RoadmapEpics.md) dependency chain (vault crypto before editor before indexer before RAG).

---

## Versioning surfaces (four layers)

| Layer | Identifier | Example | Owned by | Consumer |
|-------|------------|---------|----------|----------|
| **Application** | Semver `MAJOR.MINOR.PATCH` | `0.3.1` | Xcode target / `CFBundleShortVersionString` | Users, support, release notes |
| **NDL schema** | `ndlVersion` string | `0`, `0.1` | `NoteDSL/`, parser/serializer | `.owdoc` payload, import/export |
| **Vault bundle** | `bundleFormatVersion` integer | `1` | `manifest.json` | `VaultStore`, migration runners |
| **ADR** | Sequential `NNNN` | `0003` | `docs/adr/` | Engineering history |

These layers **do not move in lockstep**. A patch app release may fix UI bugs without changing NDL. A minor app release may add NDL block kinds and require a **forward-compatible** parser. A major bundle bump may require a **one-way migration** tool.

---

## 1. Application versioning (semver)

### Rules

Follow [Semantic Versioning 2.0.0](https://semver.org/):

- **MAJOR** — Breaking user workflows, minimum macOS bump, or vault format migration that **cannot** auto-run (rare; prefer bundle migration).
- **MINOR** — New epics shipped (e.g. RAG panel, graph view), new NDL kinds with backward-compatible read.
- **PATCH** — Bug fixes, performance, copy; no schema change.

### Pre-1.0 convention

While `0.x`:

- **MINOR** (`0.1` → `0.2`) may break on-disk formats **with** documented migration in release notes.
- Treat `0.x` as “public beta” for early adopters importing Obsidian folders.

### Mapping to roadmap

| Master plan phase | Typical app version band |
|-------------------|--------------------------|
| MVP (Phase 1) | `0.1.x` |
| v1 (Phase 2 epics) | `0.2.x` – `0.9.x` |
| v1 stable | `1.0.0` |
| v2 (sync, plugins) | `1.x` / `2.0.0` when sync breaks assumptions |

See [OpenWriteMasterPlan.md — Phased roadmap](./OpenWriteMasterPlan.md#phased-roadmap) and [RoadmapEpics.md — Phase 2](./RoadmapEpics.md#how-phase-2-maps-to-the-master-plan).

### Release artifacts

- Tag git: `v0.3.1`
- Changelog section per layer touched (app, NDL, bundle)
- No reference trees in release binaries ([reference trees policy](./OpenWriteMasterPlan.md#reference-trees-policy))

---

## 2. NDL schema versioning

NDL is defined in [OpenWriteMasterPlan.md — NDL v0](./OpenWriteMasterPlan.md#note-dsl-spec-ndl-v0). Schema version is stored **inside each document** (recommended: `VaultDocument.metadata["ndlVersion"]` or envelope header in serialized blob).

### Version string rules

| Change | Bump | Example |
|--------|------|---------|
| New optional block kind, new optional attribute | Minor (`0` → `0.1`) | Add `.table` kind |
| Stricter parser (was lenient) | Minor with migration note | Reject ambiguous indent |
| Removed kind, renamed field, indent rule change | Major (`0` → `1`) | Drop `.property` syntax |
| Encryption wrapper only | Bundle layer, not NDL | — |

### Compatibility matrix (target)

| Reader \ Writer | Same minor | Older minor | Newer minor |
|-----------------|------------|-------------|-------------|
| **Same** | Full | Forward-read unknown kinds as `.paragraph` + raw | N/A |
| **Older app** | Warn on unknown kinds | Full | Best-effort read |
| **Newer app** | Full | Migrate on open optional | Full |

### Parser obligations

1. **Unknown kind** — Deserialize to fallback kind; preserve raw line in `attributes["ndl.raw"]` if needed.
2. **Unknown attribute** — Preserve in `attributes` map.
3. **Round-trip tests** — Golden files per `ndlVersion` in test target ([E-02 acceptance](./RoadmapEpics.md#e-02-ndl-editor-v1)).

### Export interchange

Markdown export does **not** carry `ndlVersion`; it is a **lossy view**. Re-import via [E-07](./RoadmapEpics.md#e-07-import-markdown--obsidian) may not restore all block kinds until import mappers are updated.

---

## 3. Vault bundle format versioning

### Layout (v0 sketch → format version 1)

From [master plan — Vault bundle](./OpenWriteMasterPlan.md#vault-bundle-v0):

```
MyVault.openwrite/
  manifest.json       # bundleFormatVersion, doc index, crypto params (no keys)
  index/              # search + vector metadata (encrypted in v1)
  documents/
    {uuid}.owdoc      # encrypted NDL payload + doc metadata
```

### `manifest.json` (normative fields)

| Field | Type | Description |
|-------|------|-------------|
| `bundleFormatVersion` | `Int` | Monotonic; migration runners key off this |
| `createdAt` | ISO8601 | Vault creation |
| `documents` | `[{ id, title, path }]` | Registry |
| `crypto` | object | Algorithm, KDF params, salt id — **no keys** |
| `appVersionCreated` | semver string | Provenance |

### `.owdoc` envelope (per document)

Recommended inner plaintext JSON or binary framing before AEAD:

| Field | Description |
|-------|-------------|
| `ndlVersion` | Schema of serialized tree |
| `payload` | UTF-8 NDL or binary AST |
| `metadata` | Tags, template, dates |

Encryption: ChaCha20-Poly1305 or AES-GCM via CryptoKit ([E-01](./RoadmapEpics.md#e-01-vault-encryption-v1)).

### Bundle version history (planned)

| `bundleFormatVersion` | App era | Changes |
|----------------------|---------|---------|
| `0` | MVP stub | In-memory only / dev |
| `1` | v1 | CryptoKit AEAD, manifest + `documents/*.owdoc`, `index/` |
| `2` | v1.1+ | Encrypted index blobs; snapshot files (optional) |
| `3` | v2 | Sync metadata blocks (if product adds sync) — **speculative** |

---

## 4. Migration policy

### Principles

1. **Open beats lose** — Prefer reading old data with warnings over refusing to open.
2. **Explicit migration** — User sees “This vault was created with an older format; upgrading…” for irreversible steps.
3. **Backup before migrate** — Copy `MyVault.openwrite` to `MyVault.openwrite.backup-YYYYMMDD` automatically.
4. **Atomic writes** — Write to temp file, `rename` into place ([E-01 acceptance](./RoadmapEpics.md#e-01-vault-encryption-v1)).
5. **No network** — Migrations are local scripts inside the app.

### Migration runner (conceptual)

```
VaultMigrationCoordinator
  ├── requiredVersion: Int (from manifest)
  ├── steps: [MigrationStep]  // 1→2, 2→3, ...
  └── run() throws
        for step in steps where step.from == current:
            step.upgrade(vaultURL)
            update manifest.bundleFormatVersion
```

Each `MigrationStep` documents: **from**, **to**, **idempotent?**, **rollback?** (usually rollback = restore backup only).

### NDL migrations

- **In-place on load** — Bump `ndlVersion` in memory when parser normalizes legacy syntax.
- **Batch tool** — Menu: “Upgrade all notes to NDL 0.1” re-saves every `.owdoc`.
- Never migrate encrypted blobs without unlock.

### Index migrations

`index/` format may change independently. Rebuild from decrypted NDL is always allowed (slower but safe). [E-04](./RoadmapEpics.md#e-04-fsevents-indexer) should detect index version mismatch and trigger rebuild.

### Import vs migration

| Operation | Source | Target | Versioning |
|-----------|--------|--------|------------|
| **Import** | External `.md` folder | New docs in vault | Importer version in report |
| **Migration** | Same vault, older bundle | Same vault, newer bundle | `bundleFormatVersion` bump |
| **Export** | Vault | `.md` files | Lossy; no bundle version |

---

## 5. ADR numbering and lifecycle

### Location

`docs/adr/NNNN-short-title.md` — four-digit zero-padded sequence.

### When to write an ADR

- Cross-cutting architecture (local-only, RAG stack)
- Data model choices (typed pages)
- Reversing a prior decision
- External dependency stance (LM Studio vs Ollama)

### Template

Each ADR includes:

- **Status:** Proposed | Accepted | Deprecated | Superseded by ADR-XXXX
- **Context**
- **Decision**
- **Consequences**
- **Links** to master plan, epics, other ADRs

### Current index

| ADR | Title | Status |
|-----|-------|--------|
| [0001](./adr/0001-local-only-architecture.md) | Local-only architecture | Accepted |
| [0002](./adr/0002-typed-pages-object-model.md) | Typed pages object model | Accepted |
| [0003](./adr/0003-reor-rag-in-swift.md) | Reor-style RAG in Swift | Accepted |

New ADRs take the next integer; do not renumber merged PRs.

### Relationship to semver

- **ADR accepted** does not bump app version.
- **ADR implements breaking bundle change** — ship with MINOR/MAJOR app bump + migration step + changelog.

---

## 6. Compatibility checklist (release gate)

Before tagging a release, verify:

- [ ] `bundleFormatVersion` documented if changed
- [ ] NDL golden tests pass for all supported `ndlVersion` values
- [ ] Migration from previous `bundleFormatVersion` tested on sample vault
- [ ] Older app (previous tag) can open vault **or** user sees clear upgrade path
- [ ] [RoadmapEpics](./RoadmapEpics.md) acceptance criteria for touched epics
- [ ] ADR updated if decision changed

---

## 7. Examples

### Example A: Add callout block (non-breaking)

- NDL: `0` → `0.1` (new kind)
- Bundle: unchanged (`1`)
- App: `0.2.0` MINOR
- Migration: none; old apps ignore unknown kind on read if following forward-compat rules

### Example B: Encrypt index directory

- Bundle: `1` → `2`
- App: `0.3.0` MINOR
- Migration: `MigrationStep1to2` encrypts existing index or deletes and rebuilds
- User message: “Re-indexing vault (one time)…”

### Example C: v2 sync metadata (future)

- Bundle: `2` → `3`
- ADR: new `0004-sync-metadata.md` (when written)
- App: `2.0.0` MAJOR if v1 vaults require mandatory migration

---

## Document maintenance

Update this framework when:

- `manifest.json` fields change
- NDL v0 graduates to v1
- [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md) vault or NDL sections change
- Phase 2 epics complete ([RoadmapEpics.md](./RoadmapEpics.md))

*Owner: OpenWrite core. Process doc; not shipped in app bundle unless copied to Resources deliberately.*
