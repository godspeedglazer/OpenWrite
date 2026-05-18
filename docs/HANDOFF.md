# OpenWrite — UI refactor handoff

**Last updated:** 2026-05-17  
**Scope:** Frontend perception pass (Refactor Phase 0) — not backend, NDL grammar, or vault crypto.

**Full project handoff:** [../HANDOFF.md](../HANDOFF.md) (KNOWN BROKEN, verify steps, writing-core scope).

---

## KNOWN BROKEN (verify after rebuild)

| Symptom | Status |
|---------|--------|
| Welcome editor CPU/RAM fork-bomb | **Addressed** — see root HANDOFF; editor uses SwiftUI `ScrollView`, not nested `OpenWriteThemedScrollView` |
| Blank white editor on launch | **Addressed** — Welcome selection + Editor tab + block host initial layout |
| Source Serif fallback banner (Release) | **Open** — font target membership |
| Block text clipping in cards | **Open** — `OWPreviewBlockRow` |
| P0 header polish (emoji popover, cover gallery) | **Open** — UI refactor backlog |

---

## What agents did vs what shipped

Several commits (`cfcff62`, `706218e`, `99d9da1`) improved measure/apply separation but **did not stop the loop on all machines** because NSScrollView remeasure and 1pt intrinsic height collapse remained. Documentation often cited an older HEAD. Treat **clean rebuild + Activity Monitor** as the acceptance gate, not commit messages alone.

---

## How to verify

1. Quit app → Clean Build Folder → Debug build.  
2. Launch: Editor tab, Welcome body visible, CPU &lt; 15% idle, RAM stable &lt; ~500 MB.  
3. `git log -1` matches your pull.

---

## Writing core

Stability-only changes to `EditorView`, `OWBlockEditorView`, `BlockEditorPasteCaptureView`, `OpenWriteThemedScrollView` (chat path). No Affine rewrite.

---

## Inline AI

Selection **right-click** → refine presets; toolbar **Refine**; result sheet (`InlineAssistController`). See [design/InlineAIEditing.md](./design/InlineAIEditing.md).

---

### Implementation snapshot (2026-05-17)

| Area | Shipped in code |
|------|-----------------|
| **Shell** | `AnytypeShellView` — custom `OWNavigationRail` + resizable center card; `OWShellTitleBar` tabs; AI assist **collapsed by default** (`AIAssistBottomBar` to expand). |
| **Editor column** | `EditorView` — **SwiftUI `ScrollView`** for document body; `editorScrollLayoutToken` on scroll `.id` for chrome toggles. |
| **Chat** | `ChatPanelView` — `OpenWriteThemedScrollView(scrollToBottomOnTokenChange: true)`; 2×2 composer board; honest connect + 30s timeout. |
| **Editor layout** | Block paste host: read-only `sizeThatFits`; apply on structure/width only; keystrokes → `notifyContentHeightMayHaveChanged`. |
| **Graph** | `GraphView` — layout clamp, empty overlay. |
| **Out of scope** | In-app browser, cloud sync, real vault crypto. |

Canonical UI spec: [design/UIRefactorBrief.md](./design/UIRefactorBrief.md). Audit: [design/CurrentUIAudit.md](./design/CurrentUIAudit.md).

---

## Start here

| Role | Read |
|------|------|
| Implementing agent | [AGENT_PROMPT_UI_REFACTOR.md](./AGENT_PROMPT_UI_REFACTOR.md) |
| Canonical spec | [design/UIRefactorBrief.md](./design/UIRefactorBrief.md) |
| Honest status | [design/CurrentUIAudit.md](./design/CurrentUIAudit.md) |
| P0 checklist | [design/FrontendPriorities.md](./design/FrontendPriorities.md) |
| Recent fixes | [../BUGFIXES.md](../BUGFIXES.md) |

---

## What “done” looks like

1. Bundled serif loads on macOS Release builds (no warning banner).
2. Block editor shows full multi-line text inside rounded cards.
3. Page header: cover gallery, draggable icon, stable emoji picker.
4. Welcome/editor **stable** under Activity Monitor after clean rebuild.
5. [CurrentUIAudit.md](./design/CurrentUIAudit.md) P0 rows updated where applicable.

---

## Constraints

- **Native SwiftUI** — no Anytype Electron/TS stack.
- **Unicode icons only** — [design/OWIcons.md](./design/OWIcons.md).
- Match `DesignTokens` / `OWTypography`; no drive-by refactors.

---

## Code hubs

| Area | Path |
|------|------|
| Shell | `OpenWrite/OpenWrite/UI/Shell/AnytypeShellView.swift` |
| Editor | `OpenWrite/OpenWrite/UI/EditorView.swift` |
| Block host | `OpenWrite/OpenWrite/UI/Editor/OWBlockEditorView.swift` |
| Scroll (chat) | `OpenWrite/OpenWrite/UI/Design/OpenWriteThemedScrollView.swift` |
| Page header | `OpenWrite/OpenWrite/UI/Design/OWPageHeaderEditor.swift` |
