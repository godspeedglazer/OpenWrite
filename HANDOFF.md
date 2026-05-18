# OpenWrite — Project Handoff

**Version:** 1.0  
**Date:** 2026-05-17  
**Branch:** `main` (HEAD `3e5849e` + working-tree shell/editor polish)  
**Audience:** Next engineer, designer, or Cursor agent taking ownership

This document is the **single honest snapshot** of OpenWrite as it exists today. Read it before touching code. For the mandated next workstream, start with **[AGENT_PROMPT_UI_REFACTOR.md](./AGENT_PROMPT_UI_REFACTOR.md)**.

---

## 1. Executive summary

### What OpenWrite is meant to be

OpenWrite is a **local macOS app-of-apps**: one encrypted vault where you **write** (NDL block trees), **link** (wikilinks, graph), **structure** (typed pages + user-defined databases), and optionally **research** (LM Studio RAG) — without accounts, Electron, or cloud-by-default.

**Product equation:** Editor (NDL) + Typed pages (`PageType` / `PageProperties`) + User-defined databases (`OWDatabase`).

**Posture:** **Writing-first, AI-second** (Reor “dual-generator” model). The LLM retrieves and suggests when invoked; it does not own the center column.

### Current state (honest)

| Area | Reality |
|------|---------|
| **UI / shell** | **Phase 0 largely landed** — custom rail, flush titlebar accessory, centered editor column, collapsible Reor-style assist strip, themed scroll remeasure. Still not App Store “done”; needs visual QA on user machines. |
| **Backend / vault** | In-memory demo vault + encryption **stubs**. No production `.openwrite` package, Keychain unlock, or FSEvents indexer on disk. |
| **RAG / AI** | **Largely scaffolded:** `LMStudioClient`, `RAGService`, `EmbeddingService`, `InMemoryVectorStore`, `IngestionPipeline` exist; end-to-end answers with citations, persisted index, and streaming are incomplete. |
| **NDL / editor** | Block model + partial parser + `OWBlockEditorView` / preview rows — **not** a Logseq-grade outliner (no indent/outdent, slash menu, drag reorder). |
| **Documentation** | Strong: master plan, ADRs, design canon, 357-row feature matrix, epics. Code has not caught up to docs. |

**Bottom line:** The repo is a **well-documented Phase 1–2 scaffold** with recent UI iteration (themes, shell, graph fix) that still fails the bar set in [docs/ProductDirection.md](docs/ProductDirection.md) and [docs/design/FrontendPriorities.md](docs/design/FrontendPriorities.md).

---

## 2. Repo map

```
OpenWrite/                          ← Git-tracked product root
├── HANDOFF.md                      ← This file
├── AGENT_PROMPT_UI_REFACTOR.md     ← Copy-paste prompt for UI refactor agent
├── README.md                       ← Build instructions + doc hub pointer
├── BUGFIXES.md                     ← 2026-05-17 sweep log (theme, graph, vault)
├── .gitignore                      ← Reference trees + build artifacts ignored
├── docs/                           ← Authoritative product & architecture docs
│   ├── README.md                   ← Documentation hub (start here for depth)
│   ├── ProductDirection.md         ← Writing-first, Anytype aesthetics, competitor roles
│   ├── OpenWriteMasterPlan.md      ← Vision, phases, competitor inventory
│   ├── FeatureParityMatrix.md      ← 357 rows: done / partial / planned / wont
│   ├── RoadmapEpics.md             ← E-01 … E-10 Phase 2 epics
│   ├── design/                     ← UI canon (tokens, typography, anti-patterns)
│   ├── Architecture/               ← Layers, data model, AI pipeline
│   ├── features/                   ← Per-feature specs
│   ├── adr/                        ← 0001 local-only, 0002 typed pages, 0003 Reor RAG
│   └── NDL/                        ← Note Design Language v0
└── OpenWrite/                      ← Xcode project (shipping target)
    ├── OpenWrite.xcodeproj
    └── OpenWrite/                  ← Swift sources (~88 files)
        ├── App/                    ← OpenWriteApp, AppDelegate, launch
        ├── AI/                     ← LM Studio, RAG, agents, embeddings
        ├── Core/                   ← Vault, crypto, graph, indexing, theme, Past Writes
        ├── Design/                 ← DesignTokens, OWTypography
        ├── Models/                 ← VaultDocument, OWDatabase, PageType, …
        ├── NoteDSL/                ← NoteBlock, NDLParser
        ├── UI/                     ← Shell, editor, graph, database, AI panels
        └── Resources/Fonts/        ← Inter + Source Serif 4 (bundled)
```

### Gitignored vendor / reference trees (local clones only)

These paths are listed in `.gitignore` and **must not be committed or modified** by product work. Clone locally for study; port **only** into `OpenWrite/` under license rules (§8).

| Path | Upstream | License | Role |
|------|----------|---------|------|
| `reor-main/` | Reor | AGPL-3.0 | RAG, chunking, dual-generator AI behavior |
| `logseq-master/` | Logseq | AGPL-3.0 | Outliner, block UUID, graph patterns |
| `massCode-main/` | massCode | AGPL-3.0 | Snippet-store demand proof → `OWDatabase` presets |
| `AFFiNE-canary/` | AFFiNE | MIT (frontend) / EE server | Workbench, tabs, collections (no BlockSuite) |
| `rem-main/`, `rem/`, `REM*/` | rem+ | MIT | LM Studio patterns, Past Writes lineage |
| `anytype-ts-develop/` | Anytype Desktop | **ASAL 1.0** | **Inspiration only — no code copy** |
| `buffer/` | Buffer.app | Proprietary | Publish-queue UX reference only |

Also ignored: `build/`, `DerivedData/`, `node_modules/` inside clones, `.env`, secrets.

### Reference screenshots (not in git by default)

Product direction references live captures under the Cursor workspace assets folder (see [docs/ProductDirection.md](docs/ProductDirection.md) § Reference captures). Copy into `docs/assets/product-direction/` if you want them versioned.

---

## 3. What's built — feature maturity

Statuses: **done** = usable on `main`; **partial** = scaffold or weak UX; **broken** = regresses or embarrasses in demo.

| Feature | Status | Notes / primary code |
|---------|--------|----------------------|
| **Vault (in-memory)** | partial | `VaultStore`, `VaultSnapshot`, sample docs; reconcile on delete/import |
| **Vault encryption (real)** | partial / broken for prod | `EncryptionService` protocol stub; no CryptoKit disk vault |
| **NDL model** | partial | `NoteBlock`, `NDLParser` — not full round-trip or outliner ops |
| **Block editor UI** | partial (improved) | `OWBlockEditorView`, `OWPreviewBlockRow`, `EditorView` — formatting toolbar, preview mode, centered column, list inset fix |
| **Typed pages** | partial | `PageType`, `PageProperties`, `TypePickerView`, `PropertyInspectorView` |
| **Page header / hero** | partial | `OWPageHeaderEditor`, `OWPageHero`, `OWPageBanner`, `CoverStyle` |
| **Universal databases** | partial | `OWDatabase`, `DatabaseTableView`, `CreateDatabaseSheet` — no full lens over all page kinds |
| **Themes (9 palettes)** | partial | `ThemeManager`, `ThemePickerView` — switching fixed in BUGFIXES.md |
| **Workbench shell** | partial (improved) | `AnytypeShellView`, `OWNavigationRail`, `OWWindowChrome`, `AIAssistStripView` — assist collapsed by default |
| **Graph view** | partial (improved) | `GraphView`, `GraphViewModel` — **932e576** fixed rects, edges, layout; not Anytype Flow quality |
| **Backlinks** | partial | `BacklinkIndex` stub |
| **LM Studio client** | partial | `LMStudioClient`, health in Settings |
| **RAG pipeline** | partial | `RAGService`, `RetrievalService`, `HybridRanker` — in-memory index only |
| **Embeddings / ingestion** | partial | `EmbeddingService`, `IngestionPipeline`, `IngestionHealth` |
| **Vault chat / related** | partial (improved) | `ChatPanelView`, `RelatedNotesView` — assist strip; 2×2 composer; scroll softlock fixed |
| **Agents registry** | partial | `AgentRegistry`, `BuiltInAgents` (Reor port notes in `ReorPortNotes.md`) |
| **Past Writes** | partial | `PastWritesService`, timeline UI, `REMImportAdapter` stub |
| **Inline AI assist** | partial | `InlineAssistController` — popover path started, not product-grade |
| **Import Markdown** | partial | `MarkdownImporter` stub |
| **Quick capture** | partial | `QuickCaptureController` stub |
| **Design tokens / typography** | partial | `DesignTokens`, `OWTypography` — serif registration fragile (§4) |
| **Unicode icons** | partial | `OWUnicodeIcon` — replaced broken custom Path icons; not full Lucide asset pipeline |
| **Bloom intro** | partial | `LaunchIntroView` — short fade; theme-safe after fixes |
| **Settings / AI config** | partial | `OpenWriteSettingsView`, `AISettingsView` |
| **Documentation hub** | done | `docs/` comprehensive |
| **Feature parity matrix** | done | 12 done / 87 partial / 222 planned / 36 wont |
| **Local-only / no telemetry defaults** | done | ADR-0001 |
| **NDL as canonical schema (design)** | done | Spec + ADR intent |
| **macOS native target** | done | SwiftUI app builds |

Authoritative row-level tracking: [docs/FeatureParityMatrix.md](docs/FeatureParityMatrix.md).

---

## 4. What's broken / embarrassing

Prioritize these in user demos and the UI refactor.

| Issue | Symptom | Context |
|-------|---------|---------|
| **Source Serif 4 “not loading” banner** | Yellow/warning strip on page header/banner | `OWTypography.isBundledSerifAvailable` false at runtime → `OWTypographyFontWarningBanner`. Fonts exist under `Resources/Fonts/` and `Info.plist` `UIAppFonts`; PostScript names must match (`SourceSerif4-Regular`, etc.). Banner is intentional honesty, still **embarrassing** if it shows in every build. |
| **Titlebar grey strip** | Native vibrancy band above cream shell on some macOS builds | `OWSolidTitlebarAccessory` + theme-frame paint; verify after theme switch / fullscreen |
| **Block editor layout** | Residual spacing edge cases in preview vs edit | Toolbar, preview mode, and scroll remeasure landed; outliner ops still missing |
| **Anytype gap** | Density / object rows vs reference captures | Assist strip capped and off by default; rail uses custom rows not `List` |
| **Graph was broken; now “OK scaffold”** | Pre-**932e576**: huge circles, bad edges, missing nodes | Fixed: rounded-rect cards, force-directed lite, border edges, all docs visible. **UI overall still weak** — graph is not the product win yet. |
| **RAG without citations** | Chat feels generic when LM Studio is up | E-03 not complete; undermines “research” story. |
| **No real vault on disk** | “Encryption” story is theoretical | Cannot dogfood as daily driver with restart persistence. |
| **Voice / dictation** | TODO stubs | `VoiceInputService` — no crash, no feature. |

See also [BUGFIXES.md](BUGFIXES.md) for fixes already applied (theme `.id()` teardown, vault reconcile, database empty schema, graph overlay).

---

## 5. Design logic (non-negotiables)

Canonical docs: [docs/design/README.md](docs/design/README.md), [docs/design/AntiPatterns.md](docs/design/AntiPatterns.md), [docs/ProductDirection.md](docs/ProductDirection.md).

### Writing-first, AI-second

- Center column **≥ 55%** width at default window size.
- **AI assist strip collapsed by default**; cap trailing assist ~360pt (`DesignTokens.Layout.assistStripMaxWidth`).
- Vault Q&A, Related, Past Writes → **assist strip** (`AIAssistStripView`), not the main landing.
- LM Studio URL, model pickers, ingestion health → **Settings** or compact footer — not a giant left-rail block.

### Visual identity

| Do | Don't |
|----|-------|
| **Unicode / open icons** via `OWUnicodeIcon` / `OWIcon` (Lucide/Phosphor direction) | **SF Symbols** (`Image(systemName:)`) in product UI |
| **Serif typography** — Source Serif 4 bundled; route via `OWTypography` / `DesignTokens.Typography` | Inter/SF-only chrome; raw `Font.body` in product surfaces |
| **Custom shell:** `OWNavigationRail`, `OWSidebarRow`, `OWPageHero`, `OWRoundedRect` | HIG `NavigationSplitView` + blue `List` selection as product IA |
| **One accent** (OpenWrite teal-blue tokens) | User `accentColor` as brand |
| **Anytype aesthetics** (density, gradient banner, filled empty states) | Anytype **code**, assets, hex, or ASAL ports |
| **Bloom intro** &lt; 0.5s then workbench | AI-first launch or multi-second splash |

### Icons specifically

- **No custom broken Path icons** (removed in favor of Unicode).
- **No SF Symbols** in product surfaces (grep should stay clean; code blocks may use system mono only).

### Section order in rail

**OBJECTS → DATABASES → VAULT** (serif small-caps labels) — not Settings.app ordering.

---

## 6. Commits (recent landmarks)

Read with `git show <hash>`. Messages are the changelog.

| Hash | Summary |
|------|---------|
| **3e5849e** | Tighten chat composer vertical layout in assist strip. |
| **60d5513** | Fix editor preview mode toggle relayout in block host. |
| **04bffeb** | Flush titlebar chrome, theme Create page sheet, Solarized cover preset. |
| **58aeca5** | Redesign chat composer with 2×2 action board and text insets. |
| **fbf8f28** | `Ship OpenWrite product slice: design system, docs hub, and Reor-style AI.` — `DesignTokens`, typed pages, workbench inspector tabs, LM Studio RAG scaffolding, Past Writes, docs hub, app icon. |
| **97901f1** | `Ship Anytype/Logseq shell slice: themes, databases, and graph.` — Nine themes, `OWDatabase` + table UI, `AnytypeShellView`, `GraphView`/`GraphViewModel`, agent registry, ingestion pipeline ports, Inter fonts bundled. |
| **d22bb44** | `fix(ui): unicode icons, editable header, status dot, image paste, submenus` — `OWUnicodeIcon`, header editor, AI panel header, block editor fixes, `BUGFIXES.md` started. |
| **932e576** | `fix(graph): rect nodes, layout spacing, and edge rendering` — Graph layout/edges; `OWPageHeaderEditor`, sidebar sections, typography expansion, vault attachments, cover styles. |

Earlier: **0ce1c1c** (window on launch), **ad26135** (initial scaffold).

---

## 7. How to build and run

### Requirements

- macOS 14.0+
- Xcode 15+

### Command line

```bash
cd /Users/erichspringer/Downloads/OpenWrite/OpenWrite
xcodebuild -scheme OpenWrite -configuration Debug build
```

On success, open the app:

```bash
open ~/Library/Developer/Xcode/DerivedData/OpenWrite-*/Build/Products/Debug/OpenWrite.app
# or, if you build with -derivedDataPath:
open /Users/erichspringer/Downloads/OpenWrite/build/DerivedData/Build/Products/Debug/OpenWrite.app
```

### Xcode

1. Open `OpenWrite/OpenWrite.xcodeproj`
2. Select scheme **OpenWrite**, destination **My Mac**
3. **Run** (⌘R)

### Bundle ID

`com.openwrite.app`

### LM Studio (optional, for AI demos)

1. Run LM Studio locally with OpenAI-compatible API enabled.
2. In OpenWrite **Settings → AI**, set base URL (default `http://127.0.0.1:1234`).
3. Expect graceful errors if the server is down — do not assume RAG works out of the box.

---

## 8. License / OSS policy

**Shipping code lives only in `OpenWrite/`** (and `docs/`). Reference trees stay local and gitignored.

| Source | License | May port code into OpenWrite? |
|--------|---------|-------------------------------|
| **Reor** (`reor-main/`) | AGPL-3.0 | **Yes** — Swift clean-room ports; **link/comply** (notices, source offer, legal review) |
| **Logseq** (`logseq-master/`) | AGPL-3.0 | **Yes** — same as Reor |
| **massCode** (`massCode-main/`) | AGPL-3.0 | **Yes** — same as Reor |
| **AFFiNE** (`AFFiNE-canary/`) | MIT frontend | **Yes** for MIT paths + attribution; **no** EE server / BlockSuite bundle |
| **rem+** (`rem-main/`, etc.) | MIT | **Yes** — preserve MIT copyright |
| **Anytype** (`anytype-ts-develop/`) | ASAL 1.0 | **No** — **inspiration only**; no copy, adapt, or ship snippets |
| **Buffer** (`buffer/`) | Proprietary | **No** — UX reference only |

When porting, update the matching `docs/features/*.md` file and attribution per [docs/Contributing/DocumentationStandards.md](docs/Contributing/DocumentationStandards.md).

OpenWrite’s **own** license for the product tree should be decided by owners (not fixed in this handoff); third-party fonts in `Resources/Fonts/` include `LICENSE.txt` (Inter OFL; Source Serif 4 OFL).

---

## 9. Next owner priorities

### P0 — FULL UI REFACTOR (blocks downloads)

**Do not** start new backend epics until the shell meets [docs/design/FrontendPriorities.md](docs/design/FrontendPriorities.md) P0 checklist.

Use the ready-made agent brief:

→ **[AGENT_PROMPT_UI_REFACTOR.md](./AGENT_PROMPT_UI_REFACTOR.md)** (copy-paste into Cursor)

Success looks like: Bloom → custom rail → **filled** editor column → collapsed AI strip → bundled serif **without** warning banner → open icons → side-by-side credibility with Anytype reference captures — **without** Anytype code.

### P1 — After UI is credible

| Priority | Epic / doc |
|----------|------------|
| Real vault encryption + Keychain | E-01, [features/VaultEncryption.md](docs/features/VaultEncryption.md) |
| NDL editor v1 (outliner ops) | E-02, [NDL/Specification.md](docs/NDL/Specification.md) |
| RAG end-to-end + citations | E-03, [Architecture/AI-Pipeline.md](docs/Architecture/AI-Pipeline.md) |
| FSEvents indexer + persisted vectors | E-04, E-05 |
| Backlinks panel | E-06 |
| Fast capture hotkey | E-09 |

### P2 — Explicit non-goals (v1)

Cloud sync, plugin marketplace, Anytype object graph / ASAL, BlockSuite whiteboard, mobile apps — see matrix **wont** rows.

---

## Quick links

| Question | Document |
|----------|----------|
| Why local / dual-generator? | [docs/ProductPhilosophy.md](docs/ProductPhilosophy.md) |
| Full vision + phases | [docs/OpenWriteMasterPlan.md](docs/OpenWriteMasterPlan.md) |
| UI P0 checklist | [docs/design/FrontendPriorities.md](docs/design/FrontendPriorities.md) |
| What not to ship in UI | [docs/design/AntiPatterns.md](docs/design/AntiPatterns.md) |
| Epics & acceptance | [docs/RoadmapEpics.md](docs/RoadmapEpics.md) |
| Competitive rows | [docs/FeatureParityMatrix.md](docs/FeatureParityMatrix.md) |
| Git / vendor policy | [docs/GitWorkflow.md](docs/GitWorkflow.md) |
| Bug sweep 2026-05-17 | [BUGFIXES.md](BUGFIXES.md) |

---

*Handoff author: agent session 2026-05-17. Update this file when layout, maturity, or HEAD commit meaningfully changes.*
