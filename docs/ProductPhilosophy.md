# OpenWrite Product Philosophy

**Version:** 1.0  
**Last updated:** 2026-05-17  
**Related:** [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md) · [RoadmapEpics.md](./RoadmapEpics.md) · [UserPersonas.md](./UserPersonas.md) · [UserJourneys.md](./UserJourneys.md)

---

## What we are building

OpenWrite is a **local-first writer and research vault** for macOS. It is not a cloud knowledge OS, not a plugin marketplace, and not an AI that writes in your voice without your consent. It is a place where **you** remain one of two generators of meaning—the other is a language model you run yourself—and where the canonical record of your thinking lives in an encrypted bundle you can copy, back up, and lock.

The product philosophy is deliberately narrow: beat sprawling competitors on **simplicity and calm**, not on feature parity with every object type, sync mesh, or whiteboard canvas ever shipped. Strategic depth lives in [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md); delivery sequencing lives in [RoadmapEpics.md](./RoadmapEpics.md). This document states *why* those choices exist.

---

## Core beliefs

### 1. Local-only is the default, not a mode

Cloud sync can be valuable later; it is never the source of truth in v1. Your vault is a directory (or `.openwrite` bundle) on disk. Editing, indexing, graph traversal, and encryption/decryption happen on the Mac. Network calls exist only when **you** configure them—typically to **LM Studio** on `localhost` for embeddings and chat.

We reject the pattern where “sign in to unlock your notes.” There is no OpenWrite account, no Any-ID, no space onboarding funnel. One user, one vault, one machine as the primary contract. See [ADR 0001: Local-only architecture](./adr/0001-local-only-architecture.md).

**Implication for design:** Every feature must answer: *Does this work offline with the vault unlocked?* If not, it is optional, clearly labeled, and never required for core writing.

### 2. Dual-generator AI: human first, LLM second

OpenWrite inherits a thesis from the Reor lineage (clean-room in Swift, not shipped Electron): a personal knowledge app has **two generators**—the human author and the LLM. The human writes durable notes; the model **retrieves, summarizes, and suggests** from that corpus when asked. The model does not silently replace your voice, auto-commit drafts, or train on your vault by default.

RAG (retrieval-augmented generation) is the architectural expression of this belief: answers cite **your** block IDs and document IDs; related-notes panels surface neighbors in **your** embedding space. AI is augment, not author—stated explicitly in the [master plan principles](./OpenWriteMasterPlan.md#principles). Implementation direction: [ADR 0003: Reor-style RAG in Swift](./adr/0003-reor-rag-in-swift.md), epic [E-03 LM Studio RAG](./RoadmapEpics.md#e-03-lm-studio-rag).

### 3. Simplicity beats Anytype—for the jobs people actually do daily

Anytype excels at a rich object graph, relations, and sync narrative. OpenWrite does not try to replicate that operating system in v1. We compete on:

- **Faster capture** — inbox / hotkey / minimal chrome ([E-09 Fast capture](./RoadmapEpics.md#e-09-fast-capture))
- **Calmer editing** — native SwiftUI, no Electron tax
- **Clearer mental model** — pages and blocks, not spaces × types × relations × templates on day one
- **First-class local RAG** — LM Studio wired in, not bolted on via plugins

“Beat Anytype” in our vocabulary means **win the daily writer**, not **clone the knowledge OS**. The [competitive matrix](./OpenWriteMasterPlan.md#competitive-matrix) and P0 backlog in the master plan encode that trade-off.

### 4. Outliner + blocks: structure you can feel, not files you accidently break

Notes are not “a `.md` file with hope.” They are a **designed language**—NDL (Note Design Language)—serialized inside encrypted `.owdoc` blobs. The in-memory model is a tree of `NoteBlock` values with stable UUIDs, indent levels, and kinds (paragraph, heading, bullet, todo, wikilink, block reference, and so on).

We combine **Logseq-style outliner semantics** (Tab to indent, Enter to split, parent/child order) with **block-editor variety** (headings, code fences, callouts) without importing Logseq’s stack or AFFiNE’s BlockSuite runtime. Markdown remains an **export and interchange** format, not the canonical schema—see [NDL v0 in the master plan](./OpenWriteMasterPlan.md#note-dsl-spec-ndl-v0).

Users who think in outlines get keyboard-native depth; users who think in documents get a page title and a block tree that still feels like a document.

### 5. Privacy is architecture, not marketing copy

Privacy means:

- **Encryption at rest** for document bodies in a `.openwrite` vault ([E-01 Vault encryption v1](./RoadmapEpics.md#e-01-vault-encryption-v1))
- **Keys in Keychain**, cleared on lock
- **No default telemetry**; analytics only if explicitly opted in later
- **AI prompts** built from chunks the user’s action retrieved—not from background exfiltration of the whole vault

Threat model for MVP: stolen laptop disk and casual backup inspection—not nation-state memory attacks. We document limits honestly in the [master plan privacy section](./OpenWriteMasterPlan.md#privacy-model).

### 6. Native macOS is a feature

SwiftUI workbench, AppKit bridges only where needed, respect for sandboxing, Keychain, and Human Interface Guidelines. “Feels like a Mac app” is part of trust: window management, shortcuts, Quick Look hooks (where entitlement allows), and performance on Apple Silicon are product requirements, not polish items.

---

## What we refuse (v1)

These are intentional non-goals, not backlog oversights:

| Refusal | Rationale |
|---------|-----------|
| Mandatory cloud / account | Breaks local-first contract |
| Copying Anytype source (ASAL) | Legal and architectural poison |
| Shipping vendored AGPL/Electron trees | [Reference trees policy](./OpenWriteMasterPlan.md#reference-trees-policy) |
| Kanban, calendar, DB-as-objects parity | Scope trap; defer to v2+ |
| Plugin soup as core architecture | Native graph, search, AI first ([master plan principle 7](./OpenWriteMasterPlan.md#principles)) |
| AI as default author | Violates dual-generator model |

---

## How philosophy maps to epics

| Philosophy pillar | Primary epics | Master plan anchor |
|-------------------|---------------|-------------------|
| Local-only vault | E-01 | [Vault bundle](./OpenWriteMasterPlan.md#vault-bundle-v0) |
| Outliner + blocks | E-02 | [NDL v0](./OpenWriteMasterPlan.md#note-dsl-spec-ndl-v0) |
| Dual-generator RAG | E-03, E-04, E-05 | [AI / LM Studio](./OpenWriteMasterPlan.md#ai--lm-studio) |
| Beat Anytype on capture | E-09 | [P0 backlog](./OpenWriteMasterPlan.md#p0--must-ship-to-credibly-compete) |
| Graph without object OS | E-06 | [Backlinks](./OpenWriteMasterPlan.md#p0--must-ship-to-credibly-compete) |
| Typed pages (light) | E-02 + metadata | [P2 lightweight types](./OpenWriteMasterPlan.md#p2--selective-parity) |

---

## Decision record

Architectural choices that embody this philosophy are captured as ADRs under [`docs/adr/`](./adr/):

| ADR | Title |
|-----|-------|
| [0001](./adr/0001-local-only-architecture.md) | Local-only architecture |
| [0002](./adr/0002-typed-pages-object-model.md) | Typed pages without cloud sync |
| [0003](./adr/0003-reor-rag-in-swift.md) | Reor-style RAG in Swift |

Versioning and migration rules for schemas and bundles: [VersioningFramework.md](./VersioningFramework.md).

---

## One-sentence north star

**One vault you own; notes as a language you designed; AI that runs beside you and cites your blocks—native, encrypted, and calmer than the knowledge OS you left behind.**

For vision metrics and phased delivery, continue to [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md) and [RoadmapEpics.md](./RoadmapEpics.md).
