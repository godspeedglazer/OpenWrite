# OpenWrite User Personas

**Version:** 1.0  
**Last updated:** 2026-05-17  
**Related:** [ProductPhilosophy.md](./ProductPhilosophy.md) · [UserJourneys.md](./UserJourneys.md) · [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md) · [RoadmapEpics.md](./RoadmapEpics.md)

---

## Purpose

Personas anchor product and engineering decisions to **real jobs**, not feature checklists. When a proposal conflicts with a persona’s primary goal, we defer or redesign. These four personas cover OpenWrite’s v1 audience; they map to journeys in [UserJourneys.md](./UserJourneys.md) and to epics in [RoadmapEpics.md](./RoadmapEpics.md).

---

## Persona 1: Dr. Mara Chen — Academic Researcher

**Role:** Postdoc in computational social science; reads 30+ papers per month; maintains literature notes and project memos.

**Context:** Uses a university-issued MacBook Pro. Institutional policies discourage uploading unpublished field notes to consumer AI clouds. She already tried Obsidian (plugins broke after updates) and Anytype (onboarding felt heavy for “just write a paragraph about this paper”).

### Goals

- Capture paper summaries, hypotheses, and citations in one **private** vault.
- Ask questions across her corpus (“What did I conclude about sampling bias in 2024 notes?”) with **answers tied to specific notes**.
- Navigate **wikilinks and backlinks** without maintaining a rigid folder taxonomy.
- Import an existing **Obsidian folder** from a prior project without reformatting everything by hand.

### Frustrations

- Cloud PKM tools that require accounts and opaque sync.
- RAG tools that answer confidently but **don’t cite** which note the claim came from.
- Electron apps that spin fans during indexing and feel sluggish on battery.
- Markdown-only tools where block structure is an afterthought (plugins for queries, plugins for outlines).

### OpenWrite fit

| Need | Product answer | Epic |
|------|----------------|------|
| Local corpus + RAG | LM Studio Q&A with block citations | [E-03](./RoadmapEpics.md#e-03-lm-studio-rag) |
| Graph navigation | Backlinks + read-only graph | [E-06](./RoadmapEpics.md#e-06-backlinks-graph) |
| Migration | Obsidian folder import | [E-07](./RoadmapEpics.md#e-07-import-markdown--obsidian) |
| Trust on disk | Encrypted `.openwrite` vault | [E-01](./RoadmapEpics.md#e-01-vault-encryption-v1) |

**Success quote (target):** *“I asked my vault a question and it pointed me to the exact bullet I wrote six months ago—without sending my notes to the internet.”*

---

## Persona 2: Jordan Ellis — Professional Writer

**Role:** Non-fiction author and newsletter writer; drafts chapters, interview notes, and publish-ready excerpts.

**Context:** Switches between research mode and composition mode daily. Wants Buffer-style **publish pipelines** eventually but lives in capture and outline today. Cares about flow state more than object types.

### Goals

- **Fast capture** of ideas while reading or in a meeting—no type picker, no space selector.
- **Outliner-friendly** restructuring: promote bullets to sections, nest examples under claims.
- Export clean **Markdown** for editors and static site generators.
- Optional AI: “continue this section” or “summarize interview notes” **only when invoked**.

### Frustrations

- Anytype’s object model slowing down “open app, write sentence.”
- AFFiNE-style breadth (whiteboard, databases) when they only need a great editor.
- AI products that rewrite prose without showing what changed or why.
- Losing work to sync conflicts (wants one machine as source of truth in v1).

### OpenWrite fit

| Need | Product answer | Epic |
|------|----------------|------|
| Speed | Global quick capture → inbox note | [E-09](./RoadmapEpics.md#e-09-fast-capture) |
| Structure | NDL outliner + block kinds | [E-02](./RoadmapEpics.md#e-02-ndl-editor-v1) |
| Calm shell | Workbench: sidebar / editor / inspector | [E-08](./RoadmapEpics.md#e-08-affine-style-workbench-shell) |
| Future publish | Pipeline stub (Markdown export) | [E-10](./RoadmapEpics.md#e-10-publish-pipeline-stub) |

**Success quote (target):** *“I hit one shortcut, dumped the thought, and was back in Safari before the meeting moved on.”*

---

## Persona 3: Sam Okonkwo — Graduate Student

**Role:** Second-year MA student; coursework notes, reading responses, thesis outline.

**Context:** Limited budget; cannot pay for sync or AI subscriptions. Will run **LM Studio** with a small local model on an M-series Mac. Shares laptop with partner—**vault lock** matters.

### Goals

- One vault for the semester; **daily note** or inbox for lecture capture.
- Simple **templates** (Reading, Lecture, Task) without learning a type system.
- Search that finds “that definition from week 3” via keyword and meaning.
- Homework-friendly: works **offline** in the library.

### Frustrations

- Notion and cloud tools when Wi‑Fi is spotty.
- Logseq’s learning curve for non-power-users.
- Apps that nag for account creation before saving a single note.
- Fear of roommates or IT seeing notes on disk.

### OpenWrite fit

| Need | Product answer | Epic |
|------|----------------|------|
| Privacy | Encryption + lock on sleep | [E-01](./RoadmapEpics.md#e-01-vault-encryption-v1) |
| Templates | Light metadata + typed pages (v1) | [E-02](./RoadmapEpics.md#e-02-ndl-editor-v1), [ADR 0002](./adr/0002-typed-pages-object-model.md) |
| Findability | Hybrid search | [E-05](./RoadmapEpics.md#e-05-hybrid-search) |
| Daily use | Capture + journal/inbox convention | [E-09](./RoadmapEpics.md#e-09-fast-capture) |

**Success quote (target):** *“It’s just my notes on my Mac—and I can lock it when I close the lid.”*

---

## Persona 4: Alex Rivera — Privacy-Focused Knowledge Worker

**Role:** Security-conscious product manager; personal OS for decisions, meeting notes, and threat models.

**Context:** Uses Mullvad, local password managers, and self-hosted tools where possible. Evaluated Reor, Anytype, and Obsidian+plugins. Wants **encryption narrative they can verify** (files on disk, open formats documented) not black-box “E2E” marketing.

### Goals

- **No telemetry by default**; no accidental cloud upload.
- Transparent threat model: what encryption protects and what it does not.
- Control over **which chunks** go to the local LLM when asking questions.
- Auditability: export vault to Markdown for archival without vendor lock-in.

### Frustrations

- Reor’s Electron stack and AGPL coupling anxiety (wants native, independent implementation).
- Anytype ASAL and complexity of spaces/sync before local UX feels solid.
- Obsidian Sync and community plugins with broad filesystem access.
- Apps that phone home for “AI features.”

### OpenWrite fit

| Need | Product answer | Epic / doc |
|------|----------------|------------|
| Local-only default | No account; localhost AI | [ADR 0001](./adr/0001-local-only-architecture.md) |
| At-rest crypto | `.openwrite` + Keychain | [E-01](./RoadmapEpics.md#e-01-vault-encryption-v1), [privacy model](./OpenWriteMasterPlan.md#privacy-model) |
| Dual-generator AI | RAG with explicit retrieval | [ADR 0003](./adr/0003-reor-rag-in-swift.md) |
| Portability | NDL inside vault; MD export | [E-02](./RoadmapEpics.md#e-02-ndl-editor-v1), [E-07](./RoadmapEpics.md#e-07-import-markdown--obsidian) |

**Success quote (target):** *“I know where my data lives, what’s encrypted, and that the AI only sees what I asked it to retrieve.”*

---

## Persona comparison

| Dimension | Mara (researcher) | Jordan (writer) | Sam (student) | Alex (privacy) |
|-----------|-------------------|-----------------|---------------|----------------|
| Primary job | Synthesize literature | Draft and publish | Capture coursework | Trusted personal OS |
| AI usage | Heavy Q&A + related | Light, on-demand | Occasional summaries | Strict retrieval-only |
| Graph / links | High | Medium | Low–medium | Medium |
| Capture speed | Medium | **Critical** | High | Medium |
| Encryption story | Important | Nice | **Critical** | **Critical** |
| Import path | Obsidian folder | Markdown export | Fresh vault | Export + verify |

---

## Using personas in reviews

Before shipping an epic, ask:

1. **Which persona is the primary beneficiary?** If none, question scope.
2. **Does this respect local-only and dual-generator rules?** See [ProductPhilosophy.md](./ProductPhilosophy.md).
3. **Does it advance the P0 “beat Anytype” story** in [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md#beat-anytype--prioritized-backlog-p0p2)?

For step-by-step flows, see [UserJourneys.md](./UserJourneys.md).
