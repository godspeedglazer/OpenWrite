# OpenWrite Master Plan

**Version:** 0.1 (Phase 1 scaffold)  
**Platform:** Native macOS (Swift / SwiftUI)  
**Bundle ID:** `com.openwrite.app`  
**Last updated:** 2026-05-17

---

## Vision

OpenWrite is the ultimate **local-first writer**: a private knowledge workspace that combines deep AI research (Reor lineage), block-structured editing (Affine-inspired UX without copying code), graph-native linking (beats rigid folder silos), and publishing-ready output (Buffer-style workflows)—all on macOS with no mandatory cloud.

**North star:** One vault you own. Notes as a designed language (NDL), not plain Markdown files with accidental structure. AI that runs beside you via LM Studio (or compatible local servers), never exfiltrating your corpus by default.

**Success criteria (v1):**

- Open a locked vault in under 2 seconds on Apple Silicon with warm keychain unlock.
- Edit block-structured notes with NDL v0; round-trip lossless on disk.
- Semantic “related notes” and Q&A over the vault via local embeddings + LM Studio.
- Feel faster and calmer than Anytype for daily capture; clearer than Logseq for non-power-users; more intentional than Obsidian’s plugin soup.

---

## Principles

1. **Local by default** — Source of truth is on disk; sync is optional and explicit later.
2. **Privacy as architecture** — Vault encryption at rest; keys in Keychain; no telemetry without opt-in.
3. **Designed language, not accidental syntax** — NDL is the canonical model; Markdown is an export/view, not the master schema.
4. **AI is augment, not author** — Human remains a “generator”; RAG retrieves from *your* notes (Reor model).
5. **Native macOS** — SwiftUI, AppKit bridges only where needed; respect sandboxing and HIG.
6. **Composable blocks** — Affine-like structure (page → blocks → children) without AFFiNE/Anytype code.
7. **Extensible later** — Plugins and sync are v2+; MVP is opinionated and small.
8. **Clean room** — Learn from competitors; never ship Anytype source or non-compliant forks.

---

## Competitor Synthesis (placeholder)

*Fill in as research agents land; bullets are hypotheses to validate.*

### Reor (foundation — in-tree reference: `reor-main/`)

- **Take:** Local RAG, vector index per note, related-note sidebar, Q&A over corpus.
- **Gap for OpenWrite:** Electron stack → native Swift; unify with block editor + encrypted vault; standardize on LM Studio API.

### AFFiNE (structure reference — in-tree: `AFFiNE-canary/`)

- **Take:** Block/page model, edgeless vs doc modes, collaboration patterns (study only).
- **Gap:** No Rust/TS runtime in app; NDL + native rendering; offline-only MVP.

### Anytype (object graph)

- **Take:** Types, relations, graph-first navigation.
- **Gap:** Simpler type system in v0; faster capture; no blockchain/sync complexity in MVP.
- **Legal:** No code copy; independent object model.

### Logseq / Obsidian (outliner / files)

- **Take:** Backlinks, daily notes, plugin ecosystems.
- **Gap:** First-class block model and NDL; fewer knobs; encrypted vault default; built-in local AI.

### Buffer (publishing)

- **Take:** Draft → schedule → channel mental model.
- **Gap:** “Publish views” as NDL export targets (Markdown, thread, newsletter) in v1+.

---

## Architecture

### Layer diagram (target)

```
┌─────────────────────────────────────────────────────────┐
│  UI (SwiftUI) — Editor, Graph, AI panel, Vault unlock   │
├─────────────────────────────────────────────────────────┤
│  NoteDSL — Parse/serialize NDL v0, block tree ops       │
├─────────────────────────────────────────────────────────┤
│  Core — Vault I/O, index, Crypto, Search orchestration  │
├─────────────────────────────────────────────────────────┤
│  AI — LMStudioClient, embeddings adapter (future)       │
├─────────────────────────────────────────────────────────┤
│  On-disk — Encrypted vault bundle (.openwrite)          │
└─────────────────────────────────────────────────────────┘
```

### Module map (Xcode folders)

| Folder | Responsibility |
|--------|----------------|
| `App/` | `@main`, lifecycle, dependency wiring |
| `UI/` | Views, view models |
| `Models/` | `VaultDocument`, domain types |
| `NoteDSL/` | NDL AST, `NoteBlock`, parser v0 |
| `Core/Vault/` | Vault open/save, document registry |
| `Core/Crypto/` | `EncryptionService`, key handling |
| `AI/` | `LMStudioConfig`, `LMStudioClient` |

### Vault bundle (v0 sketch)

```
MyVault.openwrite/
  manifest.json          # version, doc ids, crypto params (no keys)
  index/                 # encrypted search/vector metadata (later)
  documents/
    {uuid}.owdoc         # encrypted serialized NDL + metadata
```

### Data flow (edit path)

1. User unlocks vault → `EncryptionService` derives data key.
2. `VaultStore` loads `VaultDocument` → NDL tree in memory.
3. UI mutates `NoteBlock` tree → dirty tracking.
4. Serialize NDL → encrypt → atomic write to `.owdoc`.

### Data flow (AI path — MVP stub)

1. User selects “Ask” or “Related” → `LMStudioClient` health check.
2. (v1) Chunk + embed notes → local vector store (Reor-inspired).
3. Retrieve top-k → prompt LM Studio chat/completions API.
4. Present citations back to block IDs in UI.

---

## Note DSL spec (v0 draft)

**NDL (Note Design Language)** is a line-oriented, human-readable serialization of a block tree. v0 optimizes for parse safety and diff-friendly storage inside encrypted documents.

### Document root

- A document has: `id` (UUID), `title`, `blocks[]`, optional `meta` map.

### Block kinds (v0)

| Kind | Prefix | Payload |
|------|--------|---------|
| paragraph | (none) | Plain text until block boundary |
| heading | `#` `##` `###` | 1–3 hashes + space + text |
| bullet | `-` | List item text |
| quote | `>` | Quoted text |
| code | ` ``` ` | Fenced code (language tag optional) |
| divider | `---` | Horizontal rule |
| link | `[[` | `[[title\|uuid]]` wikilink |

### Block boundary

- Blocks separated by blank line **or** explicit `---` divider line at column 0.
- Child blocks: indent 2 spaces (one level only in v0).

### Example

```ndl
# Project OpenWrite

Local-first writer for macOS.

- Encrypted vault at rest
- LM Studio for inference

> Principles beat features in v0.

[[Reor lineage|550e8400-e29b-41d4-a716-446655440000]]
```

### In-memory model

- `NoteBlock`: `id`, `kind`, `text`, `children: [NoteBlock]`, `attributes: [String: String]`.
- Round-trip: `NDLSerializer` (future) ↔ on-disk UTF-8 inside encrypted blob.

### Non-goals (v0)

- No collaborative CRDT; no embeddable databases; no full Markdown compatibility layer.

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

### Reor-aligned features (roadmap)

| Feature | Phase |
|---------|-------|
| Health check / model list | MVP stub |
| Chat Q&A over selection | v1 |
| Per-note embeddings + related sidebar | v1 |
| Semantic search | v1 |
| Inline “continue writing” | v2 |

### Client responsibilities

- `LMStudioClient`: URLSession, streaming (v1), error surfacing in UI.
- Pluggable `EmbeddingProvider` protocol (v1) for swap to Ollama later.

---

## Phased roadmap

### MVP (Phase 1 — current)

- [x] Master plan + Xcode scaffold
- [ ] Single-window vault browser shell
- [ ] Create/open vault UI (stub crypto)
- [ ] NDL v0 parser/serializer minimal
- [ ] LM Studio health check button
- [ ] One note edit/save encrypted round-trip

### v1

- Full vault encryption (CryptoKit)
- Block editor with keyboard shortcuts
- Vector index + related notes panel
- Q&A panel with citations
- Backlinks graph view (read-only)
- Export: Markdown, plain text

### v2

- Sync provider abstraction (optional)
- Plugin sandbox API
- Publish pipelines (Buffer-like queues)
- iOS companion (if product direction holds)
- Advanced NDL: tables, embeds, typed properties

---

## Legal / compliance

- **Clean room:** OpenWrite is an independent implementation. Study AFFiNE, Anytype, Logseq, Obsidian, Reor, and Buffer for *ideas and UX patterns* only.
- **No Anytype code:** Do not copy or adapt Anytype source, assets, or SDKs. Object-graph concepts may be reimplemented with original schemas and naming.
- **Third-party in workspace:** `reor-main/` and `AFFiNE-canary/` are reference trees; do not link their code into the app target without license review and explicit architecture decision.
- **Reor:** MIT-licensed reference for RAG behavior; reimplement in Swift rather than bundling Electron/Reor runtime.
- **Trademarks:** “OpenWrite” working title; verify naming before public release.
- **Export control / AI:** User runs local models; document that users are responsible for model licenses.

---

## Appendix: References in workspace

| Path | Role |
|------|------|
| `reor-main/` | Local AI PKM / RAG patterns |
| `AFFiNE-canary/` | Block editor / page structure study |
| `OpenWrite/` | Shipping native app (this repo’s product) |

---

*Document owner: OpenWrite core team. Update competitor bullets as research completes.*
