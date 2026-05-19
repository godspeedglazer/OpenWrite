# OpenWrite Documentation Hub

**Last updated:** 2026-05-17  
**Bundle ID:** `com.openwrite.app`  
**Platform:** macOS 14+ · Swift / SwiftUI

Welcome to the canonical documentation index for OpenWrite. This hub is the entry point for product vision, architecture, Note Design Language (NDL), contribution rules, and delivery planning.

> **Rule of thumb:** If it ships in the app or changes vault/NDL on disk, it must be documented here (or linked from here) before merge. See [Contributing/DocumentationStandards.md](./Contributing/DocumentationStandards.md).

---

## Start here

| Audience | Read first | Then |
|----------|------------|------|
| **UI refactor agent** | [**HANDOFF.md**](./HANDOFF.md) · [**AGENT_PROMPT_UI_REFACTOR.md**](./AGENT_PROMPT_UI_REFACTOR.md) | [design/UIRefactorBrief.md](./design/UIRefactorBrief.md), [design/CurrentUIAudit.md](./design/CurrentUIAudit.md) |
| New contributor | [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md) (vision, do not duplicate in full) | [Architecture/Overview.md](./Architecture/Overview.md) |
| iOS/macOS engineer | [Architecture/Overview.md](./Architecture/Overview.md) | [Architecture/DataModel.md](./Architecture/DataModel.md), Swift tree under `OpenWrite/OpenWrite/` |
| NDL / editor work | [NDL/Specification.md](./NDL/Specification.md) | [NDL/Migration.md](./NDL/Migration.md) |
| AI / search work | [Architecture/AI-Pipeline.md](./Architecture/AI-Pipeline.md) | [Glossary.md](./Glossary.md) (RAG, dual-generator) |
| Designer | [design/README.md](./design/README.md) | [ProductPhilosophy.md](./ProductPhilosophy.md) |
| PM / planning | [**MajorPlan-2026-05.md**](./MajorPlan-2026-05.md) (current phases) | [ProductDirection.md](./ProductDirection.md), [RoadmapEpics.md](./RoadmapEpics.md) |
| Designer (visual target) | [**ProductDirection.md**](./ProductDirection.md) § Visual | [design/OpenWriteDesignLanguage.md](./design/OpenWriteDesignLanguage.md) |

---

## Product & vision

| Document | Description |
|----------|-------------|
| [**ProductDirection.md**](./ProductDirection.md) | **Firm grasp** — what OpenWrite is (app of apps), writing-first / AI-second layout, Anytype-inspired custom rects, competitor roles, gaps vs [FeatureParityMatrix](./FeatureParityMatrix.md), 30-day UI priorities; links user reference captures. |
| [**OpenWriteMasterPlan.md**](./OpenWriteMasterPlan.md) | **Authoritative** product vision, competitor synthesis, architecture target, NDL v0 summary, privacy model, phased roadmap (MVP → v2). Link here; do not paste the full plan into other docs. |
| [**ProductPhilosophy.md**](./ProductPhilosophy.md) | Why local-first, dual-generator AI, simplicity vs Anytype, outliner + blocks, privacy-as-architecture. |
| [**RoadmapEpics.md**](./RoadmapEpics.md) | Phase 2 implementation epics (E-01 … E-10), dependencies, acceptance criteria, Swift module mapping. |
| [**FeatureParityMatrix.md**](./FeatureParityMatrix.md) | Competitive parity vs Logseq, AFFiNE, Anytype, Reor, Obsidian; Pass 1 absorption; epic/ADR links per row. |
| [UserPersonas.md](./UserPersonas.md) | *Planned* — primary personas and jobs-to-be-done. |
| [UserJourneys.md](./UserJourneys.md) | *Planned* — capture → edit → research → export flows. |
| [VersioningFramework.md](./VersioningFramework.md) | *Planned* — vault bundle, NDL, and index schema versioning. |

---

## Architecture

| Document | Description |
|----------|-------------|
| [**Architecture/Overview.md**](./Architecture/Overview.md) | Layer diagram (mermaid), module map aligned to `OpenWrite/OpenWrite/`, dependency rules, data flows. |
| [**Architecture/DataModel.md**](./Architecture/DataModel.md) | Vault bundle, `.owdoc`, encryption, `VaultDocument`, typed pages, properties, index metadata. |
| [**Architecture/AI-Pipeline.md**](./Architecture/AI-Pipeline.md) | Indexing → chunk → embed → hybrid retrieve → RAG → citations; LM Studio integration. |

---

## Note Design Language (NDL)

| Document | Description |
|----------|-------------|
| [**NDL/Specification.md**](./NDL/Specification.md) | **Full NDL v0 grammar**, block kinds, serialization, examples, parser/serializer contract. |
| [**NDL/Migration.md**](./NDL/Migration.md) | Version bumps (v0 → v0.1 → v1), vault compatibility, migration playbooks. |

Master plan NDL summary (shorter): [OpenWriteMasterPlan.md § Note DSL](./OpenWriteMasterPlan.md#note-dsl-spec-ndl-v0).

---

## Design (UI/UX)

| Document | Description |
|----------|-------------|
| [**HANDOFF.md**](./HANDOFF.md) | UI refactor handoff index (Phase 0). |
| [**AGENT_PROMPT_UI_REFACTOR.md**](./AGENT_PROMPT_UI_REFACTOR.md) | Copy-paste agent prompt for UI refactor sessions. |
| [**design/UIRefactorBrief.md**](./design/UIRefactorBrief.md) | Canonical UI refactor spec (failures, targets, component order). |
| [**design/CurrentUIAudit.md**](./design/CurrentUIAudit.md) | Brutal area × status × fix audit table. |
| [**design/FrontendPriorities.md**](./design/FrontendPriorities.md) | P0 checklist (failed/partial) + Refactor Phase 0. |
| [**design/README.md**](./design/README.md) | Design language index, principles, relationship to `DesignTokens.swift`. |
| [design/OpenWriteDesignLanguage.md](./design/OpenWriteDesignLanguage.md) | *Planned* — principles, visual identity, layout grammar. |
| [design/Tokens.md](./design/Tokens.md) | *Planned* — semantic colors, typography, spacing. |
| [design/Components.md](./design/Components.md) | *Planned* — sidebar, workbench, editor, inspector, capture, graph, AI panel. |
| [design/Motion.md](./design/Motion.md) | *Planned* — durations, curves, reduced motion. |
| [design/Accessibility.md](./design/Accessibility.md) | *Planned* — VoiceOver, contrast, keyboard focus. |

---

## Features (by capability)

Feature docs describe **user-visible behavior**, acceptance criteria, and links to epics. One doc per major capability is preferred.

| Document | Epic | Status |
|----------|------|--------|
| [features/README.md](./features/README.md) | — | Feature doc index |
| [features/VaultEncryption.md](./features/VaultEncryption.md) | E-01 | *Partial* |
| [features/VaultAndFileTree.md](./features/VaultAndFileTree.md) | E-08, E-07 | *Spec* |
| [features/TypedPagesAndStructures.md](./features/TypedPagesAndStructures.md) | E-02 | *Partial* |
| [features/GraphView.md](./features/GraphView.md) | E-06 | *Partial* |
| [features/Workbench.md](./features/Workbench.md) | E-08 | *Partial* |
| [features/ImportExport.md](./features/ImportExport.md) | E-07, E-10 | *Partial* |
| [features/PastWrites.md](./features/PastWrites.md) | — | *Partial* |
| [features/vault-encryption.md](./features/vault-encryption.md) | E-01 | *Planned* (kebab alias — prefer `VaultEncryption.md`) |
| [features/ndl-editor.md](./features/ndl-editor.md) | E-02 | *Planned* |
| [features/lm-studio-rag.md](./features/lm-studio-rag.md) | E-03 | *Planned* |
| [features/hybrid-search.md](./features/hybrid-search.md) | E-05 | *Planned* |
| [features/backlinks-graph.md](./features/backlinks-graph.md) | E-06 | *Planned* (prefer `GraphView.md`) |
| [features/fast-capture.md](./features/fast-capture.md) | E-09 | *Planned* |
| [features/workbench-shell.md](./features/workbench-shell.md) | E-08 | *Planned* (prefer `Workbench.md`) |

Parity tracking: [FeatureParityMatrix.md](./FeatureParityMatrix.md). Until remaining kebab-case files exist, use [RoadmapEpics.md](./RoadmapEpics.md) epic sections as the source of truth.

---

## Architecture Decision Records (ADR)

ADRs capture **irreversible or expensive** choices. New ADRs use the next sequential number; see [Contributing/DocumentationStandards.md](./Contributing/DocumentationStandards.md).

| ADR | Title |
|-----|-------|
| [adr/README.md](./adr/README.md) | ADR index and template |
| [adr/0001-local-only-architecture.md](./adr/0001-local-only-architecture.md) | Local-only architecture |
| [adr/0002-typed-pages-object-model.md](./adr/0002-typed-pages-object-model.md) | Typed pages without cloud sync |
| [adr/0003-reor-rag-in-swift.md](./adr/0003-reor-rag-in-swift.md) | Reor-style RAG in Swift (clean-room) |

---

## Reference & glossary

| Document | Description |
|----------|-------------|
| [**Glossary.md**](./Glossary.md) | Terms: NDL, dual-generator, typed page, vault, LM Studio, `.owdoc`, etc. |
| [**GitWorkflow.md**](./GitWorkflow.md) | Branches, conventional commits, tracked vs reference-only trees. |

---

## Repository map (documentation ↔ code)

```
OpenWrite/                          # Xcode app (tracked)
  OpenWrite/
    App/                            # @main, VaultStore injection
    Models/                         # VaultDocument, PageType, PageProperties
    NoteDSL/                        # NoteBlock, NDLParser, NDLSerializer
    Core/
      Vault/                        # VaultStore
      Crypto/                       # EncryptionService
      Indexing/                     # IndexerService
      Retrieval/                    # RetrievalService, HybridRanker
      Graph/                        # BacklinkIndex
    AI/                             # LMStudioClient, RAGService
    Import/                         # MarkdownImporter
    UI/                             # ContentView, EditorView, Workbench, Capture
docs/                               # This hub (tracked)
  README.md                         # You are here
  OpenWriteMasterPlan.md            # Vision (link, don’t duplicate)
  Architecture/                   # System design
  NDL/                              # Language spec + migration
  Contributing/                     # Doc standards
  design/                           # UI/UX language
  adr/                              # Decision records
  features/                         # Per-feature specs (planned)
reor-main/, AFFiNE-canary/, …       # Reference clones (gitignored, not shipped)
```

---

## Documentation maintenance

| Event | Action |
|-------|--------|
| New user-facing feature | Add or update `docs/features/<Name>.md`; link from this README and [FeatureParityMatrix.md](./FeatureParityMatrix.md). |
| Architectural change | Add ADR under `docs/adr/`; link from [Architecture/Overview.md](./Architecture/Overview.md). |
| NDL syntax change | Update [NDL/Specification.md](./NDL/Specification.md) + [NDL/Migration.md](./NDL/Migration.md). |
| Epic completed | Check boxes in [RoadmapEpics.md](./RoadmapEpics.md); update feature doc status. |
| Design token change | Update `design/Tokens.md` (when present) and `DesignTokens.swift`. |

---

## External references (not shipped)

Vendored trees are for study only. See [OpenWriteMasterPlan.md § Workspace inventory](./OpenWriteMasterPlan.md#workspace-inventory).

| Path | Use |
|------|-----|
| `reor-main/` | RAG, chunking, dual-generator behavior (AGPL — clean-room Swift only) |
| `AFFiNE-canary/` | Workbench / block UX patterns (MIT frontend) |
| `logseq-master/` | Outliner, block UUID, graph patterns (AGPL — ideas only) |
| `rem-main/` | Native LM Studio client patterns (MIT) |

---

## Quick links

- Build: root [README.md](../README.md)
- Product direction: [ProductDirection.md](./ProductDirection.md)
- Master plan: [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md)
- Epics: [RoadmapEpics.md](./RoadmapEpics.md)
- Parity matrix: [FeatureParityMatrix.md](./FeatureParityMatrix.md)
- Git: [GitWorkflow.md](./GitWorkflow.md)
