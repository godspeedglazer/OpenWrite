# OpenWrite Product Direction

**Version:** 1.1  
**Last updated:** 2026-05-17  
**Audience:** Product, design, engineering, and agents  
**Status:** Firm grasp — single page for *what we are building* and *what wins next*

**Related:** [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md) (delivery depth) · [ProductPhilosophy.md](./ProductPhilosophy.md) (beliefs) · [FeatureParityMatrix.md](./FeatureParityMatrix.md) (row-level parity) · [design/ProductDirection.md](./design/ProductDirection.md) (UI non-negotiables) · [design/OpenWriteDesignLanguage.md](./design/OpenWriteDesignLanguage.md) (visual rules) · [design/AntiPatterns.md](./design/AntiPatterns.md)

---

## Reference captures (user-provided, 2026-05-17)

These screenshots anchor visual and layout decisions (user session 2026-05-17). Paths are relative to this file into the Cursor workspace assets folder; copy into `docs/assets/product-direction/` when you want them versioned in git.

| Capture | File | What it shows | OpenWrite takeaway |
|---------|------|---------------|-------------------|
| **Current OpenWrite** | [OpenWrite UI capture](../../../.cursor/projects/Users-erichspringer-Downloads-OpenWrite/assets/image-da2d8f5b-7882-459e-a95f-6d075eb62040.png) | Three-column shell: vault list + LM Studio block, typed-page property grid, large **Vault chat** inspector | **Wrong balance today:** AI column competes with writing; LM Studio belongs in Settings, not the main rail; editor must be the widest column |
| **Anytype — Graph** | [Anytype graph capture](../../../.cursor/projects/Users-erichspringer-Downloads-OpenWrite/assets/image-1197762c-d9a7-49f0-bd84-ede96be6ce1d.png) | Light gray rail with **rounded white blocks** (Pinned, Objects); center **Graph / Flow** with force-directed nodes | Target sidebar density and modular rects; graph is a **navigation surface**, not the default home |
| **Anytype — About page** | [Anytype About capture](../../../.cursor/projects/Users-erichspringer-Downloads-OpenWrite/assets/image-9ceda726-392e-4104-9b78-f6c169a305ab.png) | Floating white panels on gray canvas; **page hero** (icon, title, metadata); block body with callout card | Target **OWPageHero**, editor canvas on white, callouts as `OWRoundedRect` — not system `Form` in the center column |

---

## 1. What OpenWrite IS

OpenWrite is a **local macOS app of apps**: one encrypted vault where you **write**, **link**, **structure**, and optionally **research** — without signing in, without shipping Electron, and without making the LLM the product.

The product stack is three layers:

| Layer | What it is |
|-------|------------|
| **Editor** | NDL block tree on every page — outliner, headings, wikilinks, callouts |
| **Typed pages** | `PageType` + `PageProperties` — task, reference, book, journal, and extensible kinds |
| **User-defined databases** | **`OWDatabase`** — vault-local tables you define (schema + views); rows are pages or linked records |

Snippets, manuscripts, reading lists, and CRM-lite contact lists are **presets**, not separate apps. One vault holds many databases; each database is a lens over structured rows, not a second filesystem.

| We are | We are not |
|--------|------------|
| Native SwiftUI workbench (vault → pages → blocks → **databases**) | A Markdown-only folder editor (Obsidian clone) |
| Canonical **NDL** inside encrypted `.owdoc` blobs | Plain `.md` as source of truth |
| Typed pages + **OWDatabase** presets you extend (light Anytype sets, without ASAL) | Full Anytype object OS, sync mesh, or ASAL code |
| Wikilink graph + backlinks (planned) | Block-level Datalog or plugin marketplace |
| **Writing-first** surface with optional local AI | AI-first chat app that happens to have notes (Reor UI mistake) |
| AFFiNE-inspired **navigation shell** (tabs, inspector, collections, **table views**) | AFFiNE BlockSuite / whiteboard / cloud backend |
| **Ultimate database** — one vault, many schemas you own | A single-purpose snippet app (massCode) locked to code fragments only |

**Mental model:** One vault you own. Inside it: **pages** (typed objects), each with a **block tree** (NDL). Beside pages: **databases** (`OWDatabase`) — filtered table views over those pages (snippet store, book outline, task board, anything you schema). Around that: **workbench chrome** (sidebar, editor, inspector). Beside you: **LM Studio** on localhost when you ask — never by default authoring for you.

**North star (unchanged):** [ProductPhilosophy.md](./ProductPhilosophy.md) — *one vault; notes as a designed language; AI that cites your blocks.*

**Database canon:** [features/DatabasePresets.md](./features/DatabasePresets.md) — built-in presets, schema examples, massCode → Snippet Store mapping.

---

## 2. Writing-first, AI-second (Reor dual-generator)

### Thesis

From the Reor lineage ([ADR 0003](./adr/0003-reor-rag-in-swift.md), [features/ReorAIAgents.md](./features/ReorAIAgents.md)): two generators — **you** and the **LLM**. You produce durable notes; the model **retrieves, summarizes, and suggests** when invoked. No silent auto-commit, no default cloud model, no full-screen “Ask AI” over the manuscript.

### Layout rules (non-negotiable for v1 UI)

| Rule | Target | Anti-pattern (see current capture) |
|------|--------|-----------------------------------|
| **Editor is hero** | Center column ≥ 55% of content width at default window size | Chat inspector ~50% width |
| **Inspector is secondary** | Trailing panel **collapsed by default** or capped at **320pt**; toggle “AI & tools” | Always-open wide chat |
| **Vault chat ≠ inline edit** | Q&A, related notes, Past Writes → inspector tabs ([EditorAndAIPanel.md](./design/EditorAndAIPanel.md)) | Vault chat as primary landing |
| **Selection assist is inline** | Refine/rewrite at selection (popover → Apply); does not steal column width | Duplicating chat in a sheet for every action |
| **LM Studio is operator config** | Settings sheet or compact sidebar footer | Full **LM Studio** section in left rail |
| **Citations visible** | Assistant output shows chunk / note sources ([E-03](./RoadmapEpics.md#e-03-lm-studio-rag)) | Generic “Ask your vault” with no traceability |

**Proportions (Reor `MainPage` concept, native):**

```
┌─ Sidebar (~240pt) ─┬──── Editor (flex, min ~480pt) ────┬─ Inspector (0 or ≤320pt) ─┐
│ OWSidebarRow list  │  OWPageHero + block editor        │ Chat | Related | Past      │
│ + nav sections     │  (widest, brightest text)         │ (collapsed default)       │
└────────────────────┴───────────────────────────────────┴───────────────────────────┘
```

**AI surfaces map:**

| User intent | Surface | Generator |
|-------------|---------|-----------|
| Write / outline / link | Editor + NDL | Human |
| “What did I write about X?” | Vault chat (inspector) | LLM + RAG |
| “What relates to this note?” | Related tab | LLM + embeddings |
| “Tighten this paragraph” | Inline assist at selection | LLM, human applies |
| Index / model / URL | Settings | Operator |

---

## 3. Visual direction: Anytype-inspired custom rects, NOT Apple HIG / SF Symbols

### Principle

**Native macOS** means sandbox, Keychain, shortcuts, VoiceOver — not “every control is `List`, `Form`, SF Symbols, and system blue buttons.” OpenWrite ships a **custom shell**: calm gray rail, white editor canvas, rounded **OW Rect** cards, pill selection, **`OWIcon`** + **bundled typography** — clean-room from Anytype *density and modularity*, not pixels or assets.

**Design canon:** [design/ProductDirection.md](./design/ProductDirection.md) (resize, AI back nav) · [design/AntiPatterns.md](./design/AntiPatterns.md) (forbidden patterns) · [OpenWriteDesignLanguage.md](./design/OpenWriteDesignLanguage.md) § Custom shell.

### Do / don’t

| Do | Don’t |
|----|-------|
| `OWIcon`, `OWRoundedRect`, `OWSidebarRow`, `OWPageHero`, `OWObjectTypeChip`, `OWAIPanelHeader` ([OWComponents.md](./design/OWComponents.md)) | **SF Symbols** or `Image(systemName:)` in product UI |
| Bundled fonts via `DesignTokens.Typography` | San Francisco as default chrome typeface |
| Sidebar background ~`#F5F5F7`, editor on `editorCanvas` white | Vibrancy stacks and full-width separator soup |
| 10–12pt corner radius on cards; 36–40pt row height | System grouped `Form` as the main editor layout |
| One accent (OpenWrite teal-blue) for links and primary actions | System `.borderedProminent` / user accentColor as brand |
| Inspector back stack for AI sub-panels | Flat inspector with no way back from drill-in |
| Column resize clamps + inspector collapsed default | Anytype palette, icons, or copy |
| Graph as dedicated section with custom node styling | Skia/WebView graph port |

### Screenshot → component mapping

| Reference | Pattern | OpenWrite component / token |
|-----------|---------|----------------------------|
| Anytype Graph sidebar | White rounded blocks on gray rail | `OWSidebarRow` + `sidebarBackground` / `selectionPill` |
| Anytype About | Hero + metadata row + callout card | `OWPageHero` + `OWRoundedRect(.elevated)` for callouts |
| Current OpenWrite | Type grid + properties in center | Move type picker to **new-page sheet**; hero + properties **above** editor, not instead of it |

Implementation hub: `OpenWrite/Design/DesignTokens.swift`, `OpenWrite/UI/Workbench/OWSidebarRow.swift` (expand to full vault list).

---

## 4. Competitor roles (who teaches us what)

We **ship** only `OpenWrite/`. **OSI-licensed** reference trees (`reor-main/`, `logseq-master/`, `massCode-main/`, `AFFiNE-canary/` MIT paths, `rem-main/` and user `rem/` / `REM*/` forks) may contribute **code** when license obligations are met. **Anytype (`anytype-ts-develop/`)** is **ASAL — inspiration only** (no copy, adapt, or ship).

| Competitor | Path | License | Role | Code reuse |
|------------|------|---------|------|------------|
| **Reor** | `reor-main/` | AGPL-3.0 | **AI behavior** — dual-generator, chunk-by-heading RAG, hybrid rank, vault Q&A, related notes, agent presets | **Allowed** — port to Swift; **link/comply**; no Electron/LanceDB in release |
| **Logseq** | `logseq-master/` | AGPL-3.0 | **Outliner** — block UUID, indent/outdent, fractional order, journal pages | **Allowed** — port tree/outliner logic; **link/comply**; no CLJS/Electron stack |
| **massCode** | `massCode-main/` | AGPL-3.0 | **Demand proof** — users want structured snippet stores; OpenWrite generalizes that job to **`OWDatabase`** (any row schema, not code-only) | **Allowed** with **link/comply** — import UX and Snippet Store preset, not a second app |
| **AFFiNE** | `AFFiNE-canary/` | MIT (frontend) · EE (server) | **Workbench** — tabs, inspector, collections, “All docs / Journal” nav | **MIT paths allowed** with attribution; **no** EE backend, BlockSuite, Yjs |
| **rem+** | `rem-main/`, `rem/`, `REM*/` | MIT | Swift + LM Studio patterns, search, Past Writes lineage | **Allowed** — preserve MIT notices |
| **Anytype** | `anytype-ts-develop/` | ASAL 1.0 | **Structure + UI** — typed objects, sidebar, graph entry, page hero, calm rects | **Not allowed** — IA/UX study only; OW components are independent |
| **Obsidian** | (no vendored source) | — | Wikilinks, folder metaphor, import/export | Public behavior + clean import only |
| **Buffer** | `buffer/` | Proprietary | Publish-queue mental model | **Not allowed** — UX reference only |

**Borrow vs ship (all rows):** Prefer native Swift in `OpenWrite/` over vendoring upstream runtimes (`node_modules`, Electron shells, BlockSuite).

---

## 5. What we have vs gap

**Authoritative row-level status:** [FeatureParityMatrix.md](./FeatureParityMatrix.md) (357 rows; Pass 1 summary below).

### Pass 1 landed (foundation)

| Area | Shipped / scaffolded | Docs / code |
|------|----------------------|-------------|
| Product & ADRs | Local-only, typed pages, Reor RAG direction | `docs/adr/`, master plan |
| NDL + models | `NoteBlock`, parser partial, `.owdoc` model | [NDL/Specification.md](./NDL/Specification.md) |
| Vault | `VaultStore`, encryption protocol stub | [features/VaultEncryption.md](./features/VaultEncryption.md) |
| Types | `PageType`, properties, pickers, structure templates | [features/TypedPagesAndStructures.md](./features/TypedPagesAndStructures.md) |
| Workbench | `NavigationSplitView`, `WorkbenchState`, inspector tabs | [features/Workbench.md](./features/Workbench.md) |
| AI | `LMStudioClient`, `RAGService`, chat/related/agents UI | [Architecture/AI-Pipeline.md](./Architecture/AI-Pipeline.md) |
| Design system | Tokens, OW component specs, editor/AI placement ADR | `DesignTokens.swift`, [design/](./design/) |

### Critical gaps (product-visible)

| Gap | Matrix / epic | User-visible symptom |
|-----|---------------|-------------------|
| **OWDatabase v1** | v2 (post–typed pages) | No table views over custom schemas; snippet store is pages-only, not a database lens |
| **Layout: writing not primary** | E-08, design | Editor squeezed; chat dominates (see [current capture](#reference-captures-user-provided-2026-05-17)) |
| **Custom chrome not applied** | E-08, [OWComponents](./design/OWComponents.md) | Default `List` sidebar; `OWSidebarRow` not wired in `ContentView` |
| **Block editor v1** | E-02 | `TextEditor` / preview, not outliner ops |
| **Real vault crypto** | E-01 | No production `.openwrite` + Keychain unlock |
| **Graph view** | E-06 | No force-directed surface (Anytype graph target) |
| **RAG end-to-end** | E-03, E-04, E-05 | Stubs: embeddings, persisted index, streaming answers with citations |
| **Fast capture** | E-09 | No global hotkey / inbox |
| **Backlinks panel** | E-06 | `BacklinkIndex` stub only |

**Parity snapshot (from matrix):** 12 **done**, 87 **partial**, 222 **planned**, 36 **wont** — see [Statistics](./FeatureParityMatrix.md#statistics).

---

## 6. Next 30 days — UI priorities

**Window:** 2026-05-17 → 2026-06-16. Goal: *feel like Anytype’s calm shell with Reor’s AI posture* while editor and NDL remain the engineering spine.

| # | Priority | Outcome | Epic / doc |
|---|----------|---------|------------|
| 1 | **Writing-first layout** | Inspector off or ≤320pt by default; editor flex-grow; LM Studio → Settings | [EditorAndAIPanel.md](./design/EditorAndAIPanel.md), E-08 |
| 2 | **Sidebar → OWSidebarRow** | Vault list on gray rail with pill selection; remove giant LM block from rail | [OWComponents.md](./design/OWComponents.md) |
| 3 | **OWPageHero + editor canvas** | Title, type chip, metadata row above block editor (Anytype About pattern) | OWPageHero (implement per spec) |
| 4 | **Wire OWRoundedRect** | Inspector and type/new-page surfaces use OW Rect cards, not raw `Form` | `UI/Design/*`, E-08 |
| 5 | **Graph shell (read-only)** | Sidebar **Graph** opens canvas with stub layout + “link with [[wikilinks]]” empty state | [features/GraphView.md](./features/GraphView.md), E-06 |
| 6 | **Chat compact mode** | Smaller typography, tighter empty state; agent picker in header not body | [design/Components.md](./design/Components.md) § AI panel |
| 7 | **New page flow** | Type/template picker in sheet only; center column always editor | [TypedPagesAndStructures.md](./features/TypedPagesAndStructures.md) |
| 8 | **Inline assist popover** | Replace sheet scaffold with selection-anchored popover + Apply | [InlineAIEditing.md](./design/InlineAIEditing.md) |

**Explicitly not in 30-day UI:** full Anytype relation graph, whiteboard, plugin system, mobile, cloud sync ([FeatureParityMatrix](./FeatureParityMatrix.md) **wont** rows).

**Success check (30 days):** A new user opens the app and sees **a wide page to write in** first; AI is one click away, not half the window. Side-by-side with [Anytype Graph capture](#reference-captures-user-provided-2026-05-17), the rail and rects read as family; side-by-side with [current OpenWrite capture](#reference-captures-user-provided-2026-05-17), chat no longer dominates.

---

## How this doc relates to others

| Question | Read |
|----------|------|
| Why local / dual-generator? | [ProductPhilosophy.md](./ProductPhilosophy.md) |
| Epics, estimates, acceptance criteria? | [RoadmapEpics.md](./RoadmapEpics.md) |
| Competitive row pass/fail? | [FeatureParityMatrix.md](./FeatureParityMatrix.md) |
| Colors, motion, components? | [design/README.md](./design/README.md) |
| Full vision + NDL + privacy? | [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md) |
| Database presets and schemas? | [features/DatabasePresets.md](./features/DatabasePresets.md) |

*Owner: OpenWrite core. Update when layout or competitor roles change; link new reference captures in § Reference captures.*
