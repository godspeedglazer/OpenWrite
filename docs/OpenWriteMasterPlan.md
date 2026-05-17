# OpenWrite Master Plan

**Version:** 0.3 (ultimate database vision)  
**Platform:** Native macOS (Swift / SwiftUI)  
**Bundle ID:** `com.openwrite.app`  
**Last updated:** 2026-05-17

**Product & process docs:** [ProductPhilosophy.md](./ProductPhilosophy.md) · [UserPersonas.md](./UserPersonas.md) · [UserJourneys.md](./UserJourneys.md) · [VersioningFramework.md](./VersioningFramework.md) · [ADRs](./adr/) · [RoadmapEpics.md](./RoadmapEpics.md)

---

## Vision

OpenWrite is the ultimate **local-first writer and database**: a private knowledge workspace that combines a native **editor**, **typed pages**, and **user-defined databases** (`OWDatabase`) in one encrypted vault — snippets, books, tasks, references, or any schema you define. Around that core: deep AI research (Reor lineage), block-structured editing (AFFiNE-inspired UX without copying code), graph-native linking, and publishing-ready output (Buffer-style workflows)—all on macOS with no mandatory cloud.

**Product equation:** `OpenWrite = Editor (NDL) + Typed pages (PageType) + User-defined databases (OWDatabase)`.

| Layer | Role |
|-------|------|
| **Editor** | Every row has a body: NDL block tree in `.owdoc` |
| **Typed pages** | Built-in kinds + property schemas (`PageType`, `PageProperties`) |
| **OWDatabase** | Vault-local table definitions: fields, filters, sort, views; rows map to pages (or child pages) |

**North star:** One vault you own. Notes as a designed language (NDL), not plain Markdown files with accidental structure. Structured data as **your** databases, not a vendor object graph. AI that runs beside you via LM Studio (or compatible local servers), never exfiltrating your corpus by default—the **dual-generator** model: you write; the LLM retrieves and suggests.

**Database presets:** [features/DatabasePresets.md](./features/DatabasePresets.md).

**Success criteria (v1):**

- Open a locked vault in under 2 seconds on Apple Silicon with warm keychain unlock.
- Edit block-structured notes with NDL v0; round-trip lossless on disk inside encrypted `.owdoc` blobs.
- Semantic “related notes” and Q&A over the vault via local embeddings + LM Studio with citations to block IDs.
- Feel faster and calmer than Anytype for daily capture; clearer than Logseq for non-power-users; more intentional than Obsidian’s plugin soup.

---

## Principles

1. **Local by default** — Source of truth is on disk; sync is optional and explicit later.
2. **Privacy as architecture** — Vault encryption at rest; keys in Keychain; no telemetry without opt-in.
3. **Designed language, not accidental syntax** — NDL is the canonical model; Markdown is an export/view, not the master schema.
4. **AI is augment, not author** — Human remains a “generator”; RAG retrieves from *your* notes (Reor model).
5. **Native macOS** — SwiftUI, AppKit bridges only where needed; respect sandboxing and HIG.
6. **Composable blocks** — Affine-like structure (page → blocks → children) without AFFiNE/Anytype code.
7. **User-defined databases** — `OWDatabase` generalizes snippet stores, reading lists, and manuscript trackers into one vault-local abstraction; built-in **presets** ship first ([DatabasePresets.md](./features/DatabasePresets.md)).
8. **Extensible later** — Plugins and sync are v2+; MVP is opinionated and small with **native graph, search, and AI**—no plugin duct tape.
9. **License compliance** — OSI-licensed reference trees may contribute **code** when obligations are met (AGPL: link/comply; MIT: attribute). **Anytype (ASAL)** is **inspiration-only** — no copy, adapt, or ship.

---

## Workspace inventory

Six vendored reference trees live beside the shipping app. They are **local study clones**, not dependencies.

| Path | App | Tech | License | Size / notes |
|------|-----|------|---------|--------------|
| `reor-main/` | **Reor** (stated foundation) | TS, React, Electron, LanceDB, Transformers.js | **AGPL-3.0** — code OK, **link/comply** | ~43k LOC; local RAG + markdown vault |
| `AFFiNE-canary/` | AFFiNE | Yarn monorepo, BlockSuite, optional Rust | **MIT** (frontend); **EE** on `packages/backend/server` | ~358k LOC; MIT paths portable; no EE server |
| `anytype-ts-develop/` | Anytype Desktop | TS, Electron, Vite, Bun | **ASAL 1.0** — **no code copy** | ~197k LOC; inspiration only |
| `logseq-master/` | Logseq | ClojureScript, Electron, SQLite graph | **AGPL-3.0** — code OK, **link/comply** | ~250k LOC; outliner + block graph |
| `massCode-main/` | massCode | Electron, snippets/notes | **AGPL-3.0** — code OK, **link/comply** | ~75k LOC; **proves snippet-store demand** → OpenWrite **Snippet Store** preset on `OWDatabase` |
| `rem-main/` | rem+ (user fork: `rem/`, `REM*/`) | Native Swift, SQLite, LM Studio | **MIT** — code OK, attribute | Screen-memory + semantic search patterns |

**Also present (not vendored source):**

| Path | Role |
|------|------|
| `OpenWrite/` | **Shipping product** — Xcode app (tracked in git) |
| `docs/` | Master plan, workflow docs |
| `buffer/` | Buffer.app binary (`com.returnlabs.buffer`) — publish UX reference only |
| `Obsidian (…)/` | Empty placeholder — closed-source competitor |
| `OpenWrite Project Folder/` | Empty legacy placeholder |

**Blockers resolved in Phase 1:** OpenWrite scaffold and master plan exist. Reference trees still need per-repo `npm`/`yarn`/`bun` install before building upstream.

**Recommended reading order for agents:** `reor-main/README.md` → `docs/OpenWriteMasterPlan.md` → `AFFiNE-canary` workbench modules → `logseq-master` outliner/deps → `anytype-ts-develop` (UX only, ASAL) → skip `buffer/` binary except product notes.

---

## Reference trees policy

Reference trees are **local clones** (gitignored by default), **not npm/yarn dependencies**, and **not copied wholesale** into the app bundle. OpenWrite may **port or adapt code** from OSI-licensed references when license obligations are satisfied. **Anytype** stays **ASAL — inspiration only** (no code contact).

| Repo / path | License | Code reuse in `OpenWrite/` |
|-------------|---------|---------------------------|
| `reor-main/` | **AGPL-3.0** | **Allowed** — port algorithms/UI logic into Swift; **link/comply** (source offer, notices, counsel for proprietary distribution) |
| `logseq-master/` | **AGPL-3.0** | **Allowed** — same as Reor; prefer Swift ports over shipping ClojureScript/Electron |
| `massCode-main/` | **AGPL-3.0** | **Allowed** — import UX + Snippet Store preset; product generalizes massCode’s job to **OWDatabase** |
| `AFFiNE-canary/` | **MIT** (frontend) · **EE** (`packages/backend/server`) | **Allowed** for MIT paths — workbench/block **patterns and code** with attribution; **never** embed EE backend or BlockSuite runtime in v1 |
| `rem-main/` · user `rem/` · `REM*/` | **MIT** | **Allowed** — port with MIT copyright/notice in `NOTICE` or file headers |
| `anytype-ts-develop/` | **ASAL 1.0** | **Not allowed** — UX/IA study only; independent Swift + naming |
| `buffer/` | Proprietary binary | **Not allowed** — product/UX reference only |

| Rule | Detail |
|------|--------|
| **Git** | Listed in root `.gitignore` (`reor-main/`, `AFFiNE-canary/`, `anytype-ts-develop/`, `logseq-master/`, `massCode-main/`, `rem-main/`, `buffer/`, `Obsidian*/`). Only `OpenWrite/`, `docs/`, and root `README.md` are product-tracked. |
| **Build** | No reference `node_modules` or upstream Electron app in CI/release. Shipped binary = `OpenWrite/` + SPM only. |
| **Purpose** | Study, **license-compliant porting**, UX benchmarking — not vendoring whole upstream apps. |
| **Attribution** | See [Contributing/DocumentationStandards.md](./Contributing/DocumentationStandards.md) when porting files or substantial logic. |
| **Submodules** | Optional: pin reference commits via submodule; default is “clone locally, don’t commit.” |
| **REM copies** | User may add `rem/` or `REM*/` forks; same ignore rules. Do not alter upstream folders when a separate copy is provided. |
| **Shipping** | App Store / notarized build contains **only** `OpenWrite/` sources, declared SPM deps, and required license notices. |

---

## Competitor synthesis

### Reor (foundation — AGPL; port with link/comply)

**Thesis:** *“A RAG app with two generators: the LLM and the human.”* Q&A and related-notes augment writing; Writing Assistant was never shipped in upstream UI.

| Inherit (behavior) | Replace (implementation) |
|--------------------|---------------------------|
| Dual-generator RAG, hybrid vector + keyword search | Electron + React + Tamagui soup |
| Vault directory as truth; chunk-by-heading index | LanceDB in Node → SQLite/GRDB + vector extension |
| Per-note embeddings, related sidebar, agent tools | Bundled Ollama → **LM Studio** OpenAI-compatible API |
| `[[wikilink]]`, chat with citations | BlockNote web editor → **NDL** + native SwiftUI |
| OpenAI-compatible `apiURL` config | `electron-store` plaintext → **Keychain + encrypted vault** |

**Critical Reor paths (spec only):** `electron/main/common/chunking.ts`, `electron/main/vector-database/`, `src/lib/db.ts`, `src/lib/llm/chat.ts`, `src/components/Chat/index.tsx`.

**Do not replicate:** forced dark mode, React Native in Electron, PostHog in a privacy product, full-screen indexing gate before edit, shipping Reor’s Electron runtime or commingled AGPL blobs without compliance.

---

### AFFiNE (structure — MIT frontend; EE backend)

**Take:** Workbench shell (tabs + active view), **View Islands** (route-owned header/body/inspector), root explorer (All docs, Journal, collections/tags), block tree with page vs edgeless modes, database blocks as lenses.

**Gap for OpenWrite:** No BlockSuite/Yjs/TS runtime; no whiteboard/kanban parity in v1. Borrow **navigation chrome** and **smart collections** (filter rules over doc IDs), not CRDT cloud stack.

**License trap:** `packages/backend/server` and native packages are **Enterprise Edition**—do not embed AFFiNE server in OpenWrite.

**SwiftUI mapping:** `NavigationSplitView` + per-tab `NavigationPath`; trailing inspector for AI/related-notes (Reor) and outline; `CollectionRuleEngine` as saved predicates over note metadata.

---

### Logseq / Obsidian (outliner + files)

**Logseq (AGPL):** Block UUID, parent, fractional order, outliner ops, SQLite authoritative store with markdown interchange (`pages/`, `journals/`, `- ` bullets). **May port logic to Swift** with AGPL link/comply; do not ship Logseq’s Electron+CLJS stack.

**Obsidian:** No source in workspace; public plugin API = `Vault` + `Workspace` + CodeMirror 6. User pain: plugin fragility, paid sync, Electron lag, file-only model forcing plugins for block queries.

**OpenWrite stance:** **Outliner-first NDL** with native block graph (backlinks, block refs) built in—beat “install 15 plugins” without copying Logseq’s Electron+CLJS stack.

**Vault navigation (hybrid):** One encrypted registry (flat `.owdoc` files), with **optional virtual folder tree**, **flat/smart-list sections** (All, Inbox, Journal, Types), and **typed pages**—not a second filesystem or Anytype object graph. Detail: [features/VaultAndFileTree.md](./features/VaultAndFileTree.md).

| From Obsidian | From Logseq |
|---------------|-------------|
| `[[wikilink]]`, vault folder mental model | Stable block IDs, parent/order, journal pages |
| Frontmatter familiarity | Outliner ops + recycle / soft delete |
| — | Worker-style background indexer |

---

### Anytype (competitor to beat — ASAL, no code copy)

**Strengths:** Local-first narrative, object types, relations, graph navigation, encryption story, P2P sync (mature vs OpenWrite MVP).

**OpenWrite response:** Native speed, simpler capture, **file-level vault crypto**, LM Studio RAG first-class, NDL + graph **without** Any-ID / space onboarding. Light typed properties in v1; defer kanban/calendar/DB-as-objects.

**Workspace:** `anytype-ts-develop/` (~79 MB) — Electron client only; no `anytype-heart` middleware in tree. **Do not copy** schemas, assets, gRPC protos, or UI strings.

---

### massCode (snippet store — market proof, not the ceiling)

**Thesis:** massCode validated that developers and writers want a **fast, structured snippet store** — folders, tags, languages, copy-to-clipboard, import from JSON.

**OpenWrite response:** Do not ship a snippet-only silo. Port **UX patterns** (quick capture, tag filter, language column, massCode JSON import) into the **Snippet Store** preset on **`OWDatabase`**. The same vault holds **Book**, **Task board**, **Reference library**, and custom schemas the user defines.

| massCode concept | OpenWrite mapping |
|------------------|-------------------|
| Snippet = title + body + language + tags | `OWDatabase` row → `VaultDocument` (`pageType: snippet` or preset schema) |
| Folders / collections | Database **views** (saved filters) or vault smart collections |
| JSON export/import | [ImportExport.md](./features/ImportExport.md) massCode path → NDL + properties |
| Electron app | Native Swift table + editor split; AGPL ports with link/comply |

**Critical paths (study only):** `massCode-main/src/main/services/store/snippets.ts`, import/export handlers, sidebar list density.

**Do not replicate:** Snippet-only product boundary; separate app identity; plaintext-only storage without vault encryption.

---

### Buffer (publishing mental model)

**In workspace:** `buffer/Buffer *.app` (menu-bar Markdown, local storage, on-device LLM per public product page). No `buffer.md` in repo.

**Borrow:** Draft → polish → **publish view** export (Markdown, thread, newsletter) in v2—not menubar-only scope.

---

## Competitive matrix

Legend: ● strong · ◐ partial · ○ weak · — not focus

| Dimension | Anytype | Buffer | AFFiNE | Reor | **OpenWrite (target)** |
|-----------|---------|--------|--------|------|------------------------|
| Primary job | Knowledge OS / object graph | Menubar capture | Notion+Miro workspace | Local AI PKM | **Writer + research vault** |
| Platform | Electron (multi) | macOS menubar | Web + desktop + mobile | Electron | **macOS native** |
| Default encryption | ● E2E spaces | ○ local files | ◐ self-host | ○ md folder | ● **`.openwrite` vault** |
| Data model | Objects, relations, DB views | Plain MD | BlockSuite + DB blocks | MD + vectors | **NDL tree** + **`OWDatabase`** (user schemas) |
| Graph / linking | ● relations | ○ | ● linked docs | ● semantic + wiki | ● wiki + graph v1 |
| Block editor | ● | ○ WYSIWYG MD | ●● | ○ | ● composable v1 |
| Local AI / RAG | ◐ | ● on-device | ◐ cloud mix | ● | ● **LM Studio** |
| Publishing | ○ export | ○ personal | ◐ share | ○ | ● pipelines v2 |
| Capture speed | ◐ type friction | ●● | ◐ | ◐ | ● **fast inbox** |
| License reuse | **ASAL — none** | N/A | MIT code OK | AGPL → link/comply | MIT + AGPL ports |

---

## Beat Anytype — prioritized backlog (P0–P2)

### P0 — Must ship to credibly compete

1. Sub-2s vault unlock (Keychain + warm unlock).
2. Encrypted `.openwrite` vault — per-document AEAD; lock on sleep.
3. **Fast capture** — global/quick entry, inbox note, minimal chrome.
4. **NDL editor v1** — core block kinds; lossless round-trip in `.owdoc`.
5. **LM Studio** — health check, Q&A with **citations to block IDs**.
6. Per-note embeddings + **related-notes** inspector (Reor pattern, Swift).
7. **Backlinks + read-only graph** without full Anytype type library.

### P1 — Differentiators

8. Semantic + keyword **hybrid search** across vault.  
9. Simple property layer — tags + a few optional fields per template.  
10. Export excellence — Markdown/PDF; publish-view templates (Buffer lineage).  
11. **No account / no Any-ID** — single-user vault ownership.  
12. Native UX — shortcuts, Quick Look, Spotlight (sandbox permitting).

### P2 — Selective parity

13. Lightweight types — Note / Task / Reference templates.  
14. Object references in blocks — embed another note.  
15. Local version snapshots inside vault.  
16. Import — Markdown / Obsidian folder (Reor-validated demand).

### Explicit non-goals (v1)

- Kanban/calendar/DB-as-objects parity with Anytype or AFFiNE canvas.  
- P2P mesh sync or multiplayer spaces before local encryption + graph excel.  
- Copying Anytype middleware, Any-ID, or ASAL code paths.

---

## Architecture

### Layer diagram (target)

```
┌─────────────────────────────────────────────────────────────┐
│  UI (SwiftUI) — Workbench, Editor, Graph, Database views, │
│                 AI inspector                                 │
├─────────────────────────────────────────────────────────────┤
│  Databases — OWDatabase schema, views, row ↔ VaultDocument  │
├─────────────────────────────────────────────────────────────┤
│  NoteDSL — NDL AST, parse/serialize, block tree ops         │
├─────────────────────────────────────────────────────────────┤
│  Core — Vault I/O, Index (FSEvents), Crypto, Search        │
├─────────────────────────────────────────────────────────────┤
│  AI — LMStudioClient, EmbeddingProvider, RAG orchestration │
├─────────────────────────────────────────────────────────────┤
│  On-disk — Encrypted vault bundle (.openwrite)              │
└─────────────────────────────────────────────────────────────┘
```

### OWDatabase (user-defined databases)

**OWDatabase** is a vault-local definition: named fields (typed properties), one or more **views** (filter, sort, visible columns), and **rows** backed by `VaultDocument` instances (same `.owdoc` encryption as notes).

| Concept | Description |
|---------|-------------|
| **Preset** | Shipped schema + default views (Snippet Store, Book, Task board, …) — [DatabasePresets.md](./features/DatabasePresets.md) |
| **Custom database** | User duplicates a preset or defines fields; stored in vault manifest / `databases/{id}.json` (format TBD) |
| **Row** | Primary key = document UUID; body in NDL; structured columns in `PageProperties` |
| **View** | Saved predicate + column layout (table, board, calendar later) |

**massCode lineage:** Snippet Store preset is the **first-class** proof-of-parity target; engineering generalizes to arbitrary `OWDatabase` schemas so books, contacts, and reading lists do not need new apps.

**Explicit non-goals (v1):** SQL engine, multi-vault federation, Anytype-style relation graph on every field, real-time collaborative cursors on table cells.

### Module map (aligned to Xcode layout)

Current scaffold under `OpenWrite/OpenWrite/`:

| Path | Status | Responsibility |
|------|--------|----------------|
| `App/OpenWriteApp.swift` | **Exists** | `@main`, `VaultStore` injection |
| `UI/ContentView.swift` | **Exists** | Vault browser shell, LM Studio health button |
| `UI/EditorView.swift` | **Exists** | Note editor placeholder |
| `Models/VaultDocument.swift` | **Exists** | Document root: id, title, blocks, meta |
| `NoteDSL/NoteBlock.swift` | **Exists** | `NoteBlock`, `Kind`, `NDLSerializer` stub |
| `Core/Vault/VaultStore.swift` | **Exists** | In-memory docs, `sealedPayload` stub |
| `Core/Crypto/EncryptionService.swift` | **Exists** | Protocol + `NoOpEncryptionService` |
| `AI/LMStudioConfig.swift` | **Exists** | Base URL, model, timeout, API key |
| `AI/LMStudioClient.swift` | **Exists** | Health check via `/v1/models` |

**Planned modules (Phase 2+ — add folders when implementing):**

| Path | Responsibility |
|------|----------------|
| `NoteDSL/NDLParser.swift` | v0 line parser, round-trip tests |
| `NoteDSL/NDLValidator.swift` | Block tree invariants |
| `Core/Vault/VaultBundle.swift` | `.openwrite` manifest, atomic writes |
| `Core/Vault/VaultUnlock.swift` | Keychain passphrase / device key |
| `Core/Crypto/CryptoKitEncryptionService.swift` | AES-GCM / ChaCha20-Poly1305 |
| `Core/Index/IndexService.swift` | FSEvents, chunk pipeline (Reor-inspired) |
| `Core/Index/VectorStore.swift` | Embeddings + hybrid rank |
| `Core/Graph/BacklinkIndex.swift` | Wiki + block ref index |
| `Core/Graph/GraphViewModel.swift` | Read-only graph layout |
| `Core/Import/ObsidianImporter.swift` | Folder → NDL (clean-room) |
| `AI/EmbeddingProvider.swift` | LM Studio `/v1/embeddings` |
| `AI/RAGService.swift` | Retrieve, prompt, cite block IDs |
| `AI/AgentConfig.swift` | Templates, tools, filters (Reor-shaped) |
| `UI/Workbench/WorkbenchState.swift` | Tabs, active view (AFFiNE-inspired) |
| `UI/Workbench/QuickCapture.swift` | Global inbox entry |
| `UI/Inspector/RelatedNotesPanel.swift` | Semantic sidebar |
| `UI/Inspector/ChatPanel.swift` | Streaming Q&A |
| `UI/Graph/GraphView.swift` | Native graph surface |
| `Databases/OWDatabase.swift` | Schema, views, row registry |
| `Databases/DatabasePreset.swift` | Built-in presets from [DatabasePresets.md](./features/DatabasePresets.md) |
| `UI/Databases/DatabaseTableView.swift` | Table lens over filtered rows |
| `Publish/ExportPipeline.swift` | MD / thread / newsletter stubs (v2) |

**Dependency rule:** `UI` → `NoteDSL`, `Models`, `Core`, `AI`. `AI` must not import `UI`. `Core` must not import `AI`.

### Vault bundle (v0)

```
MyVault.openwrite/
  manifest.json          # version, doc ids, crypto params (no keys)
  index/                 # encrypted search/vector metadata (v1)
  documents/
    {uuid}.owdoc         # encrypted serialized NDL + metadata
```

### Data flow (edit path)

1. User unlocks vault → `EncryptionService` derives data key from Keychain.
2. `VaultStore` loads `VaultDocument` → NDL tree in memory.
3. UI mutates `NoteBlock` tree → dirty tracking.
4. Serialize NDL → encrypt → atomic write to `.owdoc`.

### Data flow (AI path)

1. User selects “Ask” or “Related” → `LMStudioClient` health check.
2. `IndexService` chunks notes (heading-aware), embeds via `EmbeddingProvider`.
3. Hybrid retrieve top-k → `RAGService` prompts LM Studio chat API.
4. UI shows answers with citations linking to `NoteBlock.id`.

---

## Note DSL spec (NDL v0)

**NDL (Note Design Language)** is a line-oriented, human-readable serialization of a **block tree**. v0 merges **Logseq outliner semantics** (bullets, indent, block identity) with **AFFiNE block variety** (headings, code, callouts) while staying diff-friendly inside encrypted documents.

### Design rules

- **Canonical store:** `NoteBlock` tree in `.owdoc`; Markdown is **export**, not source of truth.
- **Stable IDs:** Every block has UUID; export may append `^blk_shortid` comments for interchange (Logseq-inspired).
- **Outliner-first:** Tab/Shift-Tab change indent level; Enter creates sibling/child per focus.
- **One indent step in v0:** 2 spaces = one child level (parser may relax in v0.1).

### Document root

- `id` (UUID), `title`, `blocks[]`, optional `meta` (tags, template, dates).

### Block kinds (v0)

| Kind | `NoteBlock.Kind` | Line prefix / syntax | Payload |
|------|------------------|----------------------|---------|
| paragraph | `.paragraph` | (none) | Plain text until boundary |
| heading 1–3 | `.heading1` … `.heading3` | `#` `##` `###` + space | Title text |
| bullet | `.bullet` | `- ` | List / outliner row |
| numbered | `.numbered` | `1. ` `2. ` … | Ordered list (v0: restart per list) |
| todo | `.todo` | `- [ ]` / `- [x]` | Checkbox item; `attributes["checked"]` |
| quote | `.quote` | `> ` | Quoted text |
| code | `.code` | fenced ` ``` ` | Body + optional `language` attr |
| divider | `.divider` | `---` at column 0 | Horizontal rule |
| wikilink | `.wikilink` | `[[title\|uuid]]` | Target title + optional UUID |
| blockref | `.blockref` | `((uuid))` | Transclusion pointer (Logseq-style) |
| callout | `.callout` | `> [!note]` etc. | Type in attr `callout=note\|warning\|tip` |
| property | `.property` | `key:: value` | Block or page metadata row |

**Deferred (v0.1+):** embed, image, table, database view, edgeless canvas.

### Block boundary

- Blocks separated by **blank line** or top-level `---` divider.
- Child blocks: **2-space indent** under parent (bullets and todos nest).

### Example

```ndl
# Project OpenWrite

Local-first writer for macOS.

- [ ] Ship vault encryption
  - Keychain unlock flow

> Principles beat features in v0.

key:: status
value:: active

[[Reor lineage|550e8400-e29b-41d4-a716-446655440000]]

((a1b2c3d4-e5f6-7890-abcd-ef1234567890))
```

### In-memory model

- `NoteBlock`: `id`, `kind`, `text`, `children`, `attributes`.
- `NDLSerializer` / `NDLParser` (planned): UTF-8 inside encrypted blob; index plain-text via `ast.plainText` for embeddings.

### Non-goals (v0)

- No collaborative CRDT; no full CommonMark compatibility; no Org-mode.

---

## REM integration (placeholder)

**Status:** `rem-main/` present in workspace (MIT, Jason McGhee upstream). User’s **hard-fork copy** may arrive as `rem/` or `REM*/` — same gitignore policy. Prior REM discovery agent did not complete; this section is the integration contract until the user’s fork is reviewed.

**What rem is:** macOS screen-memory (timeline, OCR, keyword search) with a growing **LM Studio semantic search** layer (`SemanticSearchService`, `LMStudioClient`). It is **not** a notes app; overlap with OpenWrite is **native Swift patterns**, not screen recording.

| REM artifact | OpenWrite use (clean-room) |
|--------------|----------------------------|
| `SemanticSearchService.swift` | Hybrid semantic + keyword fallback, connection checks |
| `LMStudioClient.swift` | Error handling, OpenAI-compatible requests (compare with `OpenWrite/AI/`) |
| `RemDatabase.swift` / SQLite migrations | GRDB schema ideas for index metadata |
| `Search.swift` | UX for unified search surface |
| `SettingsManager` Codable migration | Encrypted settings blob pattern |

**Not in scope for OpenWrite v1:** periodic screenshots, timeline scrubber, screen-recording permissions.

**“Decoder” in REM:** primarily **Swift `Codable` decoding** for settings and LM Studio JSON responses—not a markdown DSL. NDL parsing remains in `NoteDSL/`; do not conflate.

**Action when user copy lands:** diff fork vs `rem-main/`, list bug-fix highlights, update this section with file-level borrow list (MIT allows concept port; prefer rewrite in OpenWrite style).

---

## Privacy model

### Threat model (MVP)

- **In scope:** Stolen laptop disk, casual forensic access to `~/Documents`, backup drives without keys.
- **Out of scope (v0):** Live memory attacks, compromised macOS kernel, malicious full-disk access while unlocked.

### Vault at rest

- User passphrase or device-bound key via Keychain.
- Per-vault salt; AEAD (AES-GCM or ChaCha20-Poly1305 via CryptoKit) for document blobs.
- `manifest.json` may be plaintext with non-sensitive metadata; document bodies encrypted.

### Runtime

- Keys cleared on lock / app background (configurable timeout in v1).
- No network calls for core editing; AI calls only to user-configured host (default `localhost`).

### AI privacy

- LM Studio endpoint user-controlled; no default cloud model.
- Prompts include only retrieved chunks user triggered; log redaction in debug builds.

### Future

- Optional sync with E2E encryption (v2); export without keys always explicit.

---

## AI / LM Studio

### Integration stance

- **Primary backend:** [LM Studio](https://lmstudio.ai) OpenAI-compatible REST (`/v1/chat/completions`, `/v1/embeddings` when available).
- **Config:** `LMStudioConfig` — base URL, model id, timeout, API key (optional for local).
- **Reor alignment:** Replace bundled Ollama with user-managed LM Studio; port hybrid search and agent config shapes in Swift (clean-room).

### Reor-aligned features (roadmap)

| Feature | Phase |
|---------|-------|
| Health check / model list | MVP stub (**exists**) |
| Chat Q&A over selection | v1 |
| Per-note embeddings + related sidebar | v1 |
| Semantic + hybrid search | v1 |
| Inline “continue writing” | v2 |
| Agent tools (search, create note with confirm) | v2 |

### Client responsibilities

- `LMStudioClient`: URLSession, streaming (v1), error surfacing in UI.
- Pluggable `EmbeddingProvider` protocol (v1) for swap to Ollama later.

---

## Phased roadmap

### MVP (Phase 1 — current)

- [x] Master plan + Xcode scaffold
- [ ] Single-window vault browser shell
- [ ] Create/open vault UI (stub crypto → CryptoKit)
- [ ] NDL v0 parser/serializer minimal
- [ ] LM Studio health check button (**stub exists**)
- [ ] One note edit/save encrypted round-trip

### v1

- Full vault encryption (CryptoKit)
- Block editor with keyboard shortcuts (outliner)
- Vector index + related notes panel
- Q&A panel with citations
- Backlinks graph view (read-only)
- Export: Markdown, plain text
- AFFiNE-style workbench shell (tabs + inspector)

### v2

- **`OWDatabase` v1** — table views, custom schemas, Snippet Store + Book/Task/Reference presets
- massCode JSON import into Snippet Store preset
- Sync provider abstraction (optional E2E)
- Plugin sandbox API
- Publish pipelines (Buffer-like queues)
- iOS companion (if product direction holds)
- Advanced NDL: tables, embeds, board/calendar database views

---

## Agent execution phases (next 90 days)

Rough calendar for autonomous / human agents. Adjust per velocity; dependencies flow top-to-bottom.

| Phase | Weeks | Goals | Primary modules |
|-------|-------|-------|-----------------|
| **A — Vault & crypto** | 1–3 | Real `.openwrite` bundle, unlock UI, CryptoKit AEAD, one `.owdoc` round-trip | `Core/Vault`, `Core/Crypto` |
| **B — NDL v0** | 3–6 | Parser/serializer, editor binding, block kinds table above | `NoteDSL`, `UI/EditorView` |
| **C — Workbench shell** | 5–8 | Split view, sidebar sections, quick capture, doc list | `UI/Workbench` |
| **D — Index & search** | 7–10 | FSEvents indexer, chunker, keyword search | `Core/Index` |
| **E — LM Studio RAG** | 9–12 | Embeddings, hybrid rank, related panel, chat + citations | `AI/*`, `UI/Inspector` |
| **F — Graph & import** | 11–13 | Backlink index, read-only graph, Obsidian folder import | `Core/Graph`, `Core/Import` |

**Exit criteria (day 90):** Encrypted vault usable daily; NDL edit + export MD; LM Studio Q&A with citations; backlinks graph; no dependency on vendored trees in release build.

**Parallel safe work:** Phase A+B before D; C can start once `VaultDocument` stable; E needs D’s chunk store.

---

## Legal / compliance

### Anytype (ASAL — inspiration only)

- Anytype is **“open code” under ASAL 1.0**, not OSI open source. Commercial use, network deployment, and redistribution are restricted.
- **Never** copy or adapt Anytype source, assets, protobuf/gRPC definitions, type names, or UI copy into OpenWrite.
- **Never** link `anytype-ts-develop` into the app target or ship derived binaries.
- Competitive study is limited to **public behavior**, README-level concepts, and independent reimplementation with **original schemas and naming** (e.g. `VaultDocument`, `NoteBlock`, not Anytype object IDs).
- If in doubt, treat Anytype like a proprietary competitor with extra visibility into UX—**no code contact**.

### OSI-licensed references (code allowed with compliance)

| Tree | License | OpenWrite rule |
|------|---------|----------------|
| `reor-main/` | AGPL-3.0 | **May use code** (Swift ports); **link/comply**; do not ship Electron/Reor runtime without counsel |
| `logseq-master/` | AGPL-3.0 | **May use code** (Swift ports); **link/comply**; do not ship Logseq stack |
| `massCode-main/` | AGPL-3.0 | **May use code** for import/snippet UX; **link/comply** |
| `AFFiNE-canary/` | MIT + EE backend | **MIT paths:** may use/adapt with attribution; **no** EE server, BlockSuite link, or Yjs cloud stack in v1 |
| `rem-main/` · `rem/` · `REM*/` | MIT | **May use code**; preserve MIT notices in ported files or `NOTICE` |
| `buffer/` | Proprietary binary | UX reference only — **no code** |

### General

- **Attribution:** Document ports in PRs and [Contributing/DocumentationStandards.md](./Contributing/DocumentationStandards.md).
- **Trademarks:** “OpenWrite” is a working title; verify before public release.
- **Export control / AI:** User runs local models; document that users are responsible for model licenses.
- **Telemetry:** Opt-in only; no default analytics in MVP.

---

## Appendix: References in workspace

| Path | Role | Ship? | Code into `OpenWrite/`? |
|------|------|-------|-------------------------|
| `OpenWrite/` | Native macOS product | **Yes** | — |
| `docs/OpenWriteMasterPlan.md` | This document | **Yes** | — |
| `reor-main/` | RAG + vault reference | No (clone) | **Yes** (AGPL link/comply) |
| `AFFiNE-canary/` | Workbench + block reference | No (clone) | **Yes** (MIT paths only) |
| `anytype-ts-develop/` | Competitor UX (ASAL) | No (clone) | **No** |
| `logseq-master/` | Outliner + graph reference | No (clone) | **Yes** (AGPL link/comply) |
| `massCode-main/` | Snippet store demand proof → **OWDatabase** Snippet preset | No (clone) | **Yes** (AGPL link/comply) |
| `rem-main/` · `rem/` · `REM*/` | Swift LM Studio + search | No (clone) | **Yes** (MIT attribute) |
| `buffer/` | Publish UX binary | No | **No** |

### Reor entry points (quick index)

- `reor-main/README.md`
- `reor-main/electron/main/index.ts`
- `reor-main/src/lib/db.ts`
- `reor-main/src/lib/llm/chat.ts`

### AFFiNE shell entry points

- `AFFiNE-canary/packages/frontend/core/src/modules/workbench/`
- `AFFiNE-canary/packages/frontend/core/src/modules/workbench/view/view-islands.tsx`

**Obsidian import study only (do not ship):** `AFFiNE-canary/blocksuite/affine/widgets/linked-doc/src/transformers/obsidian.ts` — Markdown/wikilink/callout mapping reference for E-07; OpenWrite import stays clean-room Swift ([ImportExport.md](./features/ImportExport.md)).

### Logseq entry points

- `logseq-master/deps/outliner/`
- `logseq-master/deps/graph-parser/`

---

*Document owner: OpenWrite core team. Version 0.2 merges workspace inventory, Reor/AFFiNE/Logseq/Anytype/Buffer research agents, and Phase 1 scaffold paths.*
