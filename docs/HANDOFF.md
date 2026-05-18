# OpenWrite — UI refactor handoff

**Last updated:** 2026-05-17  
**Scope:** Frontend perception pass (Refactor Phase 0) — not backend, NDL grammar, or vault crypto.

### Current stability (2026-05-17)

| Area | Status |
|------|--------|
| **Welcome editor** | Layout loop fix in **cfcff62**; follow-up keeps `sizeThatFits` measure-only. Re-test Welcome after each editor host change. |
| **Chat** | Honest connect until first token; **30s** timeout + `diagnoseChatFailure` when server/model unavailable. |
| **Launch** | `VaultStore.bootstrapOnLaunch` selects Welcome when no document selected. |

### Implementation snapshot (2026-05-17)

| Area | Shipped in code |
|------|-----------------|
| **Shell** | `AnytypeShellView` — custom `OWNavigationRail` + resizable center card; `OWShellTitleBar` tabs; AI assist **collapsed by default** (`AIAssistBottomBar` to expand). |
| **Title bar** | `OWWindowChrome` — transparent unified titlebar, `OWSolidTitlebarAccessory` opaque fill, theme-frame paint, vibrancy strip; reapplied on theme/window events. |
| **Editor column** | `openWriteEditorContentWidth()` centers readable column (~880pt); `editorScrollLayoutToken` remeasures `OpenWriteThemedScrollView` when assist/rail toggles. |
| **Chat** | `ChatPanelView` — 2×2 composer board (`composerBoardHeight`), `scrollToBottomOnTokenChange` for transcript only; `OWChatStatusStepper` baseline-aligned rail. |
| **Scroll** | `OpenWriteThemedScrollContainer` remeasures hosting height on clip resize (deferred apply; read-only measure). |
| **Editor layout** | Block paste host: **read-only** measure in `sizeThatFits`; apply only from `updateNSView` → `scheduleLayout` — fixes Welcome SIGABRT / CPU loop. |
| **Chat timeout** | `AISafetyLimits.chatStreamTimeoutSeconds` (30s); failed connect step + diagnosis when LM Studio off. |
| **Graph** | `GraphView` + `OWRoundedRect.editorPanel` maxHeight; empty overlay when linkless; layout clamp on resize. |
| **Sheets** | `openWriteSheetPresentationChrome()` — cream `background` token on Create page / database sheets. |
| **AI / RAG** | Agent presets differ by topK, excerpt width, temperature, and answer format (`AgentRegistry`). Vault index: active-vault pages + `VaultMarkdownCatalog` `.md`; launch `prepareVaultIndex`; search timeout → lexical fallback. Settings shows index + ingestion status. |
| **Out of scope** | In-app browser, cloud sync, real vault crypto, voice dictation (`VoiceInputService` stubs). |

Canonical UI spec: [design/UIRefactorBrief.md](./design/UIRefactorBrief.md). Audit rows: [design/CurrentUIAudit.md](./design/CurrentUIAudit.md).

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

## What went wrong (summary)

User feedback and screenshots show: **Source Serif fallback banner**, **clipped block text** in filled cards, **emoji popover** placement, and **page header chrome** that mimics Anytype layout without Anytype polish. Docs still mentioned Lucide/Phosphor while code ships **Unicode-only** icons.

---

## What “done” looks like

1. Bundled serif loads on macOS Release builds (no warning banner).
2. Block editor/preview shows full multi-line text inside rounded cards.
3. Page header: cover gallery, draggable icon, stable emoji picker, options in submenu.
4. Welcome/editor empty states are **filled**, not a white void.
5. [CurrentUIAudit.md](./design/CurrentUIAudit.md) P0 rows updated to **Pass** where applicable.

---

## Constraints

- **Native SwiftUI** — no Anytype Electron/TS stack.
- **Unicode icons only** — [design/OWIcons.md](./design/OWIcons.md).
- **No commit** unless the user asks.
- Logo remains user-owned — [design/BrandAndLogo.md](./design/BrandAndLogo.md).

---

## Code hubs

| Area | Path |
|------|------|
| Shell | `OpenWrite/OpenWrite/UI/Shell/AnytypeShellView.swift` |
| Rail | `OpenWrite/OpenWrite/UI/Shell/OWNavigationRail.swift` |
| Page header | `OpenWrite/OpenWrite/UI/Design/OWPageHeaderEditor.swift` |
| Blocks | `OpenWrite/OpenWrite/UI/Design/OWPreviewBlockRow.swift` |
| Typography | `OpenWrite/OpenWrite/Design/OWTypography.swift` |
| Fonts | `OpenWrite/OpenWrite/Resources/Fonts/` |
| Tokens | `OpenWrite/OpenWrite/Design/DesignTokens.swift` |

---

## Reference images

Copy PNGs into [assets/ui-refactor/](./assets/ui-refactor/) per [assets/ui-refactor/README.md](./assets/ui-refactor/README.md).
