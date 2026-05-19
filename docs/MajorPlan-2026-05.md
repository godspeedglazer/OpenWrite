# OpenWrite Major Plan — May 2026

**Version:** 1.0  
**Last updated:** 2026-05-18  
**Branch baseline:** `rewrite/ui-spine` (workbench shell, Refine rail, vision chat, custom chrome)  
**Audience:** You + agents — single “what we’re building next” doc  

**Long-form references (unchanged):** [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md) · [RoadmapEpics.md](./RoadmapEpics.md) · [HANDOFF.md](./HANDOFF.md) · [design/FrontendPriorities.md](./design/FrontendPriorities.md)

---

## 1. Product thesis (now)

OpenWrite is **local-first writing with calm Anytype-like chrome** and **Reor-like vault AI** — native macOS only.

| Pillar | Bar for “done” |
|--------|----------------|
| **Writing** | Stable block editor, lossless NDL, no layout fork-bomb, paste/copy honest |
| **Knowledge** | Wikilinks, graph with directed edges, rail + graph search |
| **AI — Refine (hero)** | Selection → left rail stepper → stream → Apply — **this is the UX gold standard** |
| **AI — Ask vault** | Must reach Refine parity: honest connection state, scroll, citations, Apply with stepper |
| **Shell** | Cream workbench, custom traffic lights, logo branding, assist strip that doesn’t steal the page |

**North star sentence:** *“Refine feels instant and trustworthy; everything else should feel like Refine.”*

---

## 2. What’s shipped (honest inventory)

Use this to avoid re-planning solved work.

### Shell & chrome
- `AnytypeShellView` + `WorkbenchLayoutCoordinator` (single width source)
- Custom titlebar fill, `OWShellWindowControls`, brand logo in title
- Navigation rail, objects list, search with result count
- Editor / Graph mode toggle

### Writing
- `OWBlockEditorView` + per-block `NSTextView` (AppKit bridge)
- Page header (cover, icon, title), formatting toolbar, preview mode
- Wikilinks, callouts, todos, inline markdown formatting
- Text-first paste (`shouldIngestImageFromPasteboard`)

### AI
- **Refine:** `OWRefineAssistPanel` + `OWChatStatusStepper`, streaming draft, Apply + `ow` actions
- **Chat:** split composer/transcript, vision attachments (Gemma), vault search toggle, web fetch, scroll-on-grow/resize, Refine-style action panel + Apply
- LM Studio health + connection pill (still needs “always honest” polish)
- Demo vault seeder v3 (graph atlas, link chains, arrow tour)

### Graph
- Curved edges + arrowheads, filter bar, demo seed upgrade path
- Node tap → editor; selection highlights incident edges + neighbor nodes

### Not done / fragile (treat as active risk)
- Editor height / measure loop (historical fork-bomb — guard with acceptance tests)
- Chat scroll softlock (reported repeatedly — verify after every layout change)
- Encrypted vault (still stub / dev plaintext in places)
- Full hybrid index + real embeddings at scale
- OWDatabase presets (Snippet Store, etc.) — spec only

---

## 3. UX doctrine: “Refine parity”

Every AI surface should copy **Refine’s contract**, not chat’s older patterns.

| Refine does | Ask vault / graph / import should |
|-------------|-----------------------------------|
| Panel opens **immediately** on intent | Open assist UI before network wait |
| **Stepper** shows phased work (enjoyable pacing on early steps) | Same stepper component (`OWChatStatusStepper`) |
| **Streaming** visible before “done” | Stream assistant tokens; don’t freeze UI |
| **Review & apply** — explicit, no silent edits | “Apply to open note” with preview |
| Clear failure copy (LM Studio, selection) | No “not checked” dead-ends without retry |
| Compact footer metadata (model, toggles) | Composer status row aligned with actions |

**Intentional theatrics:** Refine keeps a brief **“Searching vault”** step even when retrieval is light — it gives the stepper time to read as progress. Do not remove without replacing pacing.

---

## 4. Phased roadmap (next 12 weeks)

Phases are **sequential priorities**, not calendar promises. Parallelize only where noted.

### Phase 0 — Trust the writing surface (P0, ~2 weeks)

**Exit:** User can open Welcome, type 5 minutes, switch notes, Refine a selection, RAM/CPU stable.

| ID | Work | Owner files |
|----|------|-------------|
| 0.1 | Editor body always visible; measure gate tests | `EditorView`, `OWBlockEditorView`, `BlockEditorPasteCaptureView` |
| 0.2 | No `layoutSubtreeIfNeeded` in measure hot paths | `OpenWriteThemedScrollView`, paste host |
| 0.3 | Chat transcript scroll = full content height on resize | `ChatTranscriptView`, `ChatPanelView` |
| 0.4 | Sheets/popovers don’t hide entire shell | `EditorView`, pickers |

**Acceptance:** HANDOFF §G smoke + 60s idle memory flat.

---

### Phase 1 — Refine & AI honesty (P0, ~2 weeks)

**Exit:** Refine is demo-ready; chat connection label matches reality.

| ID | Work |
|----|------|
| 1.1 | Refine: immediate panel + opening beat (selection → vault) + stream |
| 1.2 | Refine: context menu presets (Improve / Shorten / Grammar) wired |
| 1.3 | Refine: ⌘↩ Apply, Esc dismiss (keyboard) |
| 1.4 | Chat: stepper + stream parity; fix scroll; Apply actions like Refine |
| 1.5 | Connection monitor on launch + before send; pill never lies |
| 1.6 | Optional: enable light vault retrieve for Refine (config flag) |

---

### Phase 2 — Search & graph as navigation (P1, ~3 weeks)

**Exit:** Graph is a way to browse, not a poster.

| ID | Work |
|----|------|
| 2.1 | Graph: click node → open note; highlight selected node/edges |
| 2.2 | Graph: search filters edges (dim non-incident) not only nodes |
| 2.3 | Rail search: snippet preview + jump-to-block |
| 2.4 | Vault-wide search surface (cmd+F) sharing index with chat retrieve |
| 2.5 | Demo corpus maintenance: link chains, arrow QA pages |

---

### Phase 3 — Writing core v2 (P1, ~4 weeks)

**Exit:** One layout width; editor refactor per TARGET_ARCHITECTURE.

| ID | Work |
|----|------|
| 3.1 | `WorkbenchLayoutState` only — delete duplicate width prefs |
| 3.2 | Document-level paste hub (images) |
| 3.3 | Evaluate single-`NSTextView` vs lightweight block rows (spike) |
| 3.4 | Slash menu / block insert palette (minimal) |
| 3.5 | Outliner: Enter/Tab block ops |

Reference: [.cursor/swarm/T-rewrite-001/TARGET_ARCHITECTURE.md](../.cursor/swarm/T-rewrite-001/TARGET_ARCHITECTURE.md)

---

### Phase 4 — Vault & index truth (P0 product, ~4 weeks)

**Exit:** Encrypted `.openwrite`, real embeddings, citations to block IDs.

| ID | Work |
|----|------|
| 4.1 | CryptoKit AEAD + Keychain unlock (E-01) |
| 4.2 | FSEvents indexer + chunker (E-04) |
| 4.3 | Embeddings via LM Studio + hybrid rank (E-03, E-05) |
| 4.4 | Citation links jump to block in editor |

Maps to [RoadmapEpics.md](./RoadmapEpics.md) E-01–E-06.

---

### Phase 5 — Databases & import (P2, later)

- OWDatabase Snippet Store preset (massCode lineage)
- Obsidian folder import
- Publish pipeline stub (Buffer mental model)

---

## 5. What we are not doing (v1)

- Anytype code copy (ASAL)
- AFFiNE BlockSuite / Yjs / EE backend
- Cloud sync, multiplayer, mobile
- Kanban/calendar parity
- Replacing LM Studio with bundled models

---

## 6. Agent execution rules

1. **Refine is the UX reference implementation** — extend its patterns, don’t invent new chrome per feature.
2. **Verify on Debug build** after layout/editor/chat touches — user runs uncommitted Xcode state.
3. **Minimal diffs** — no drive-by refactors.
4. **Docs:** Update this file’s §2 inventory when a phase exits; link PRs to phase IDs (e.g. `1.4`).
5. **Swarm:** Use [SWARM.md](./SWARM.md) only for large parallel hunts; sequential P0 fixes preferred.

---

## 7. Immediate next actions (suggested order)

1. **Phase 0.3** — Chat scroll acceptance test on resize + long transcript.  
2. **Phase 1.4** — Chat Apply + stepper parity with Refine.  
3. **Phase 2.1** — Graph click-to-open.  
4. **Phase 0.1** — Re-run Welcome body visibility after any editor layout change.  
5. **Sample docs** — Use demo v3 (Link Chain, Arrow Tour) for graph QA; add more only when a specific edge case needs it.

---

## 8. Success metrics (8-week)

| Metric | Target |
|--------|--------|
| Welcome → first keystroke | &lt; 3s after launch |
| Refine panel visible | &lt; 100ms after click |
| Refine first token | &lt; 3s on M-series + local 2B model |
| Chat scroll | Full transcript reachable after window resize |
| Idle RAM (10 min editing) | Stable, no GB climb |
| User-described “feels like Refine” | Ask vault + graph actions rated same polish |

---

*This plan supersedes ad-hoc priority lists in chat. Update **§2** when milestones land; keep [OpenWriteMasterPlan.md](./OpenWriteMasterPlan.md) as vision/competitor reference.*
