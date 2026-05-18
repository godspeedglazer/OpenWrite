# OpenWrite

Native macOS local-first writer: encrypted vault, Note Design Language (NDL), and LM Studio–backed AI research.

## Handoff (new owners & agents)

**Start here:** [HANDOFF.md](HANDOFF.md) — **Opus 4.7 execution handoff** (P0–P3 issues, acceptance criteria, file map, regression checklist). Short index: [docs/HANDOFF.md](docs/HANDOFF.md).

**UI refactor mission:** [AGENT_PROMPT_UI_REFACTOR.md](AGENT_PROMPT_UI_REFACTOR.md) — copy-paste Cursor agent brief for Anytype-level polish (no vendor code).

## Requirements

- macOS 14.0+
- Xcode 15+

## Build

```bash
cd OpenWrite
xcodebuild -scheme OpenWrite -configuration Debug build
```

Open `OpenWrite/OpenWrite.xcodeproj` in Xcode and run the **OpenWrite** target.

## Documentation

**Start at the [documentation hub](docs/README.md)** — master index for architecture, NDL, design, ADRs, features, and contribution standards.

| Document | Description |
|----------|-------------|
| [docs/README.md](docs/README.md) | Master index (link to all docs) |
| [docs/OpenWriteMasterPlan.md](docs/OpenWriteMasterPlan.md) | Product vision, competitors, phased roadmap |
| [docs/Architecture/Overview.md](docs/Architecture/Overview.md) | Layers, Swift module map, data flows |
| [docs/Architecture/DataModel.md](docs/Architecture/DataModel.md) | Vault, `.owdoc`, typed pages, index |
| [docs/Architecture/AI-Pipeline.md](docs/Architecture/AI-Pipeline.md) | Index → embed → retrieve → RAG |
| [docs/NDL/Specification.md](docs/NDL/Specification.md) | NDL v0 grammar and examples |
| [docs/RoadmapEpics.md](docs/RoadmapEpics.md) | Phase 2 epics (E-01–E-10) |
| [docs/Glossary.md](docs/Glossary.md) | Terminology |
| [docs/GitWorkflow.md](docs/GitWorkflow.md) | Branches, commits, tracked paths |
| [docs/Contributing/DocumentationStandards.md](docs/Contributing/DocumentationStandards.md) | Doc every feature PR; ADRs for architecture |

## Repository layout

| Path | Description |
|------|-------------|
| `docs/` | Documentation hub ([README](docs/README.md)) |
| `docs/OpenWriteMasterPlan.md` | Product vision (authoritative; link, don’t duplicate) |
| `docs/ProductPhilosophy.md` | Principles: local-only, dual-generator AI, simplicity |
| `docs/design/` | UI/UX design language |
| `docs/adr/` | Architecture decision records (0001–0003) |
| `docs/RoadmapEpics.md` | Phase 2 implementation epics (E-01–E-10) |
| `OpenWrite/` | Xcode project and Swift sources |
| `reor-main/`, `logseq-master/`, `massCode-main/` | Reference clones (AGPL — code may be ported to Swift with link/comply) |
| `AFFiNE-canary/`, `rem-main/` | Reference clones (MIT — may port with attribution) |
| `anytype-ts-develop/` | Reference clone (ASAL — inspiration only, no code copy) |

## Bundle ID

`com.openwrite.app`

## Status

Phase 1 scaffold — buildable shell with core type stubs. See [docs/OpenWriteMasterPlan.md](docs/OpenWriteMasterPlan.md) for MVP → v2 scope and [docs/RoadmapEpics.md](docs/RoadmapEpics.md) for Phase 2 delivery.
