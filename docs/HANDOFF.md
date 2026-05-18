# OpenWrite — UI refactor handoff

**Last updated:** 2026-05-17  
**Scope:** Frontend perception pass (Refactor Phase 0) — not backend, NDL grammar, or vault crypto.

**Full project handoff:** [../HANDOFF.md](../HANDOFF.md) (known issues, verify steps, writing-core scope).

---

## KNOWN ISSUES (verify after rebuild)

| Symptom | Current reality | Status |
|---------|-----------------|--------|
| Welcome/editor CPU-RAM fork-bomb | Editor is SwiftUI `ScrollView`; block host keeps measured height and coalesced apply | **Addressed** |
| Chat transcript clipping | `ChatTranscriptScrollView` uses SwiftUI scroll + bottom pin sentinel | **Addressed** |
| Chat state retention | In-memory transcript trimmed to 48 messages; archived threads are read-only restores | **Open risk** |
| Titlebar alignment gaps | `OWShellTitleBar` uses dynamic insets (`brandAlignsWithNavigationRail`, compact breakpoints) and still needs edge-width QA | **Open risk** |
| Theme propagation to AppKit bridges | Debounced selection + revision notification shipped, but bridge refreshes are still explicit and easy to miss | **Open risk** |
| Writing-engine correctness | Inline refine apply still uses string/range fallback; full outliner interactions remain unshipped | **Open risk** |

---

## What shipped vs planned

| Area | Shipped on `main` | Planned / not done |
|------|-------------------|--------------------|
| Editor layout safety | SwiftUI editor scroll + measured AppKit host (`OWBlockEditorView`) | Outliner-style editing feature set |
| Chat transcript behavior | Scroll clipping fix (`efd890b`), stepper/error refinements (`d24845a`, `0d1933c`) | Durable conversation persistence beyond capped in-memory chat |
| Theme switching | Debounced select + revision-aware chrome apply (`aeaebc2`) | Fully automatic propagation for every AppKit-backed surface |
| Shell chrome | Custom titlebar controls and themed chrome in `OWWindowChrome` | Final visual parity/alignment across all window states |
| Inline AI | Selection refine from menu/toolbar with result sheet + apply action | Robust apply semantics in all selection/range edge cases |

---

## Contributor verification checklist

1. Quit app, clean build folder, build Debug, relaunch.
2. Open Welcome in Editor and confirm full body renders and scrolls.
3. Idle 60s on Welcome and verify CPU/memory are stable.
4. Test chat with LM Studio off (timeout + diagnosis) and on (stream + stepper progression).
5. Scroll chat upward, then send another prompt and confirm auto-scroll only occurs when re-pinned.
6. Cycle all 13 themes from sidebar/settings and verify editor/chat/titlebar update coherently.
7. Check titlebar alignment with rail expanded, rail collapsed, and narrow window widths.
8. Confirm `git log -1 --oneline` matches expected head before reporting.

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
| **Chat** | `ChatPanelView` — `ChatTranscriptScrollView` (SwiftUI) with pinned-bottom auto-scroll, 2×2 composer board, honest connect timeout. |
| **Editor layout** | Block paste host: read-only `sizeThatFits`; apply on structure/width only; keystrokes → `notifyContentHeightMayHaveChanged`. |
| **Graph** | `GraphView` — layout clamp, empty overlay. |
| **Out of scope** | In-app browser, cloud sync, real vault crypto. |
| **Themes** | 13 palettes via `ThemeID`; debounced `ThemeManager.select`; AppKit surfaces rely on explicit revision/notification refresh hooks. |

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
| Scroll (chat) | `OpenWrite/OpenWrite/UI/AI/ChatPanelView.swift` (`ChatTranscriptScrollView`) |
| Page header | `OpenWrite/OpenWrite/UI/Design/OWPageHeaderEditor.swift` |
