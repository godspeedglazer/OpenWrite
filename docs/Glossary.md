# Glossary

**Last updated:** 2026-05-17  
**See also:** [docs/README.md](./README.md) · [NDL/Specification.md](./NDL/Specification.md)

Alphabetical reference for OpenWrite terminology. First mention in docs should link here where helpful.

---

## A

### AEAD (Authenticated Encryption with Associated Data)

Encryption mode that provides confidentiality and integrity; associated data (e.g. document UUID) is authenticated but not encrypted. OpenWrite targets **ChaCha20-Poly1305** or **AES-GCM** via CryptoKit for `.owdoc` files.

### Agent (AI)

Optional v2 subsystem for tool-using LLM workflows (search vault, draft note with confirmation). Distinct from simple Q&A RAG.

### AFFiNE

Reference app in workspace (`AFFiNE-canary/`) for workbench and block UX patterns. **MIT frontend**; Enterprise Edition backend must not ship. Not a dependency.

### Anytype

Competitor knowledge OS (ASAL license). **Inspiration only**—no code copy. OpenWrite competes on native speed, capture, and local RAG.

---

## B

### Backlink

Incoming link to a document from another document’s wikilink. Indexed by `BacklinkIndex`; shown in graph and inspector (E-06).

### Block

See **Note block**.

### Block reference (`blockref`)

NDL kind `((uuid))` pointing to another block by id (Logseq-style). Transclusion UI planned v0.1+.

### Buffer

Reference menubar app in `buffer/` for publish-workflow UX. Binary only—not linked.

### Bundle ID

`com.openwrite.app` — macOS application identifier.

---

## C

### Callout

NDL block kind for admonitions (`> [!note]`). Attributes: `callout=note|warning|tip`.

### Chunk

Segment of a note’s plain text used for embedding and lexical search. Produced by heading-aware **chunker** (see [AI-Pipeline.md](./Architecture/AI-Pipeline.md)).

### Citation

RAG answer reference to `documentID` and optional `blockID` from `RetrievalHit`. Dual-generator accountability.

### Clean room

Implementation practice: study AGPL/ASAL reference repos for behavior only; ship independent Swift code.

### CryptoKit

Apple framework for AEAD and key derivation in vault encryption (E-01).

---

## D

### Dual-generator

Product model from Reor lineage: **two generators** of knowledge—the human author and the LLM. Human writes notes; LLM retrieves and suggests from the corpus, not replace the author by default. See [ProductPhilosophy.md](./ProductPhilosophy.md), [adr/0003](./adr/0003-reor-rag-in-swift.md).

---

## E

### Embedding

Vector representation of text from LM Studio `/v1/embeddings` (or compatible). Stored in vault index for semantic search.

### Epic

Delivery unit in [RoadmapEpics.md](./RoadmapEpics.md) (E-01 … E-10).

---

## F

### Fast capture

Global/quick entry to inbox note (E-09). Minimal chrome; beats Anytype onboarding friction for daily input.

### FTS (Full-Text Search)

Lexical index over chunk plain text (SQLite FTS5 or equivalent).

---

## G

### Graph view

Read-only visualization of documents and wikilink edges (E-06). Not the full Anytype object graph.

---

## H

### Hybrid search

Combination of lexical (BM25-style) and vector (cosine) scores via `HybridRanker`. Epic E-05.

---

## I

### Inbox

Workbench section for uncategorized captured notes (quick capture destination).

### IndexerService

Protocol for indexing and removing document chunks (`Core/Indexing/IndexerService.swift`). Phase 1: `NoOpIndexerService`.

---

## K

### Keychain

macOS secure storage for vault key material after unlock. Cleared on lock.

---

## L

### LM Studio

Local LLM server with OpenAI-compatible API (`/v1/models`, `/v1/chat/completions`, `/v1/embeddings`). Default host `http://127.0.0.1:1234`. Primary AI backend for OpenWrite.

### Local-first

Source of truth on user disk; no mandatory cloud account. See [adr/0001](./adr/0001-local-only-architecture.md).

### Logseq

Reference outliner app (`logseq-master/`, AGPL). Block UUID and indent patterns inform NDL; code not shipped.

---

## M

### Manifest (`manifest.json`)

Plaintext vault metadata: document ids, crypto parameters (no keys). See [DataModel.md](./Architecture/DataModel.md).

### Markdown

Import/export interchange format. **Not** canonical storage—NDL/`VaultDocument` is.

### Master plan

[OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md) — vision, competitors, roadmap. Do not duplicate in full elsewhere.

---

## N

### NDL (Note Design Language)

Line-oriented serialization and in-memory block tree for note content. Spec: [NDL/Specification.md](./NDL/Specification.md). Current version: **v0**.

### NoOpEncryptionService

Phase 1 pass-through “encryption” for development; replace with CryptoKit in E-01.

### Note block (`NoteBlock`)

Atomic unit of content: `id`, `kind`, `text`, `children`, `attributes`. Tree forms document body.

---

## O

### `.openwrite`

Vault bundle directory or package containing `manifest.json`, `documents/`, and `index/`.

### `.owdoc`

Encrypted file per document: `documents/{uuid}.owdoc` containing JSON `VaultDocument`.

### Outliner

Interaction model: Tab/Shift-Tab indent, Enter to split bullets—Logseq-inspired, native in NDL editor.

---

## P

### Page

Synonym for **vault document** / note in UI.

### PageProperties

Typed key-value metadata bag (`PageProperties`) with schema per **PageType**.

### PageType (typed page)

Enum: `note`, `task`, `reference`, `journal`, `project`. Light object types without cloud sync. See [adr/0002](./adr/0002-typed-pages-object-model.md).

### Phase 1 / Phase 2

**Phase 1:** MVP scaffold (in-memory vault, stub crypto/AI). **Phase 2:** Epics E-01–E-10 per [RoadmapEpics.md](./RoadmapEpics.md).

### PlaceholderRAGService

Stub `RAGService` that retrieves hits and checks LM health but returns empty answer text until E-03.

### Property block

NDL `@key value` line mapping to `PagePropertyKey` / `PagePropertyValue`.

---

## Q

### Quick capture

See **Fast capture**.

---

## R

### RAG (Retrieval-Augmented Generation)

Pipeline: search vault chunks → build prompt → LM Studio completion → citations. See [AI-Pipeline.md](./Architecture/AI-Pipeline.md).

### Reference tree

Vendored gitignored clone (`reor-main/`, etc.) for study—not shipped.

### Reor

AGPL reference PKM app; dual-generator and RAG behavior spec. Swift clean-room only.

### RetrievalHit

Search result: document id, optional block id, score, snippet.

### REM / rem-main

MIT reference macOS app for LM Studio client patterns (`rem-main/`).

---

## S

### Sealed payload

Output of `EncryptionService.seal` before writing `.owdoc`.

### Semantic search

Vector similarity over embeddings.

### Sidebar section

`SidebarSection` enum driving workbench navigation (notes, inbox, graph, …).

---

## T

### Typed page

Document with `pageType` and schema-driven `PageProperties`—OpenWrite’s lightweight alternative to Anytype object types.

### TypeTemplate

Factory for default blocks and properties when creating a page of a given type.

---

## V

### Vault

User-owned encrypted corpus (`.openwrite` bundle). One vault per primary workflow in v1.

### VaultDocument

Codable document model: title, type, properties, `rootBlocks`, timestamps.

### VaultStore

`@MainActor` in-memory document store; persistence to bundle in E-01.

---

## W

### Wikilink

NDL link to another document: `[[title]]` or `[[title|uuid]]`. Kind `.wikilink`.

### Workbench

AFFiNE-inspired shell: sidebar + document list + editor + inspector (`WorkbenchState`, E-08).

---

## Symbols

### `[[…]]`

Wikilink syntax in NDL.

### `((…))`

Block reference syntax in NDL.

### `@key`

Property line prefix in NDL v0 serializer.

---

## Acronym quick reference

| Acronym | Expansion |
|---------|-----------|
| ADR | Architecture Decision Record |
| AEAD | Authenticated Encryption with Associated Data |
| API | Application Programming Interface |
| FTS | Full-Text Search |
| HIG | Human Interface Guidelines |
| KDF | Key Derivation Function |
| NDL | Note Design Language |
| PKM | Personal Knowledge Management |
| RAG | Retrieval-Augmented Generation |
| UI | User Interface |
| UUID | Universally Unique Identifier |

---

*Missing a term? Add it here in the same PR that introduces the concept.*
