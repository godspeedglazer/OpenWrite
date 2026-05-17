# OpenWrite Design Product Direction

**Version:** 1.1  
**Last updated:** 2026-05-17  
**Audience:** Design and UI implementers  
**Product scope (full):** [../ProductDirection.md](../ProductDirection.md)  
**Visual system:** [FrontendPriorities.md](./FrontendPriorities.md) · [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) · [AntiPatterns.md](./AntiPatterns.md)

This page captures **non-negotiable design direction** for the OpenWrite shell. **Downloads depend on frontend** — see [FrontendPriorities.md](./FrontendPriorities.md) for the P0 checklist and sequencing.

“Native macOS” here means **platform integration without Apple HIG as product IA** — not stock `NavigationSplitView` sidebar ordering, not SF Symbols, not Settings-shaped `Form` in the editor column.

---

## Identity: abandon HIG ordering; Anytype aesthetics, not framework

| OpenWrite is | OpenWrite is not |
|--------------|------------------|
| **Filled** calm workbench — Anytype-*quality* density (clean-room) | Hollow columns, vast margins, paragraph-only empty states |
| **Serif** display + section labels (Serifa intent → Source Serif 4 / Literata) | Inter/SF-only chrome that reads “unfinished Mac app” |
| **Lucide or Phosphor** (MIT) via `OWIcon` | SF Symbols or symmetric Apple glyph grid |
| `OWNavigationRail` — custom rail, pill rows, product section order | HIG staple `List` sidebar + system selection blue |
| macOS for sandbox, Keychain, shortcuts, VoiceOver | Anytype Electron/TS **framework** or ASAL code |

**HIG ordering ban:** Do not structure navigation like Settings.app or default split-view sidebars. Section order is **OBJECTS → DATABASES → VAULT** (see [FrontendPriorities.md § 1](./FrontendPriorities.md#1-abandon-hig-ordering-not-just-symbols)).

**SF Symbols ban:** Do not use `Image(systemName:)`, `Label(..., systemImage:)`, or SF-based `ContentUnavailableView`. See [AntiPatterns.md](./AntiPatterns.md).

**Typography requirement:** Bundled **serif** (and optional body pairing) via **`DesignTokens.Typography`** / `OWTypography` — `Resources/Fonts/`, `UIAppFonts`. System font only for monospaced code and documented AppKit exceptions.

**Logo:** Placeholder icon is dev-only; **final logo is user-owned** — [BrandAndLogo.md](./BrandAndLogo.md).

---

## Required primitives

| Primitive | Role |
|-----------|------|
| **`OWIcon`** | Single icon pipeline — **Lucide or Phosphor** SVG assets (MIT), `accent` / `textSecondary` / object-type tints |
| **`OWNavigationRail`** | Fixed-width sidebar; no system `List` selection |
| **`OWPageBanner`** | Optional gradient strip behind page icon (Anytype playground pattern) |
| **`OWRoundedRect`** | Cards, inspector sections, capture fields |
| **`OWSidebarRow`** | Vault and section navigation |
| **`OWPageHero`** | Document header and empty states |
| **`OWObjectTypeChip`** | Typed page labels |
| **`OWAIPanelHeader`** | Inspector AI chrome: title, back, optional agent picker |

Implementation specs: [OWComponents.md](./OWComponents.md).

---

## Writing-first layout (unchanged)

Center column is the hero; inspector is secondary. Default window (~1200×800): editor receives **≥ 55%** of content width; inspector **collapsed** or ≤ **320pt** when open.

Full proportions and competitor context: [../ProductDirection.md § Writing-first](../ProductDirection.md#2-writing-first-ai-second-reor-dual-generator).

---

## AI panels: back navigation

Inspector AI is not a single flat screen. Any flow that pushes **depth** (agent detail, citation source list, thread settings, Past Writes drill-in) must provide **back** to the previous level without closing the inspector.

### Rules

| Rule | Detail |
|------|--------|
| **Header** | Use `OWAIPanelHeader`: leading back `OWIcon` (`.chevronLeft` asset), center title, trailing actions |
| **Depth 0** | Vault chat / Related / Past Writes tabs — **no** back; segmented tab picker is root |
| **Depth ≥ 1** | Back returns to parent panel state; does not toggle inspector closed |
| **Keyboard** | `Escape` or `Cmd+[` pops one level when focus is in inspector AI |
| **VoiceOver** | “Back to {parent title}” |

### Example stack

```
Inspector root (tabs: Chat | Related | Past Writes)
  └─ Chat (depth 0)
       └─ Agent settings (depth 1) → back → Chat
       └─ Citation sources for message (depth 1) → back → Chat
```

Wire in: `WorkbenchInspectorView`, `ChatPanelView`, `AgentPickerView` — back mutates local navigation path, not `NavigationSplitView` column visibility.

Placement context: [EditorAndAIPanel.md](./EditorAndAIPanel.md).

---

## Resize rules

Columns are user-resizable where split views allow; clamps and collapse order are fixed so the **editor never drops below usable width**.

### Width clamps

| Zone | Min | Preferred / default | Max | Notes |
|------|-----|---------------------|-----|-------|
| Sidebar | 260 (`sidebarMinWidth`) | 272 (`sidebarPreferredWidth`) | 300 (`sidebarMaxWidth`) | Gray rail; pill rows |
| Main (editor / graph / search) | 480 (`mainMinWidth`) | flex | — | Hero column |
| Inspector | 280 (`inspectorMinWidth`) | 320 product default | 360 (`inspectorMaxWidth`) | AI + related + Past Writes |
| Editor text column | — | centered | 720 (`editorMaxContentWidth`) | Inside main, not split width |

Token source: [Tokens.md § Layout constants](./Tokens.md#layout-constants).

### Collapse priority (narrow window)

When total content width cannot satisfy mins:

1. **Collapse inspector** first (hidden; `Cmd+Option+I` restores).
2. **Collapse sidebar** second (`Cmd+Ctrl+S`).
3. **Never** shrink main below `mainMinWidth` — show horizontal scroll or minimum window size instead.

**Breakpoint:** At total window width **&lt; 900pt**, auto-collapse inspector if open (optional in settings: “Keep inspector open”).

### Resize affordances

- Use **native split dividers** between columns; do not custom-draw resize handles in v1.
- Persist user sidebar/inspector widths in `UserDefaults` / `WorkbenchState` where split APIs expose column width.
- Animate column show/hide with `Motion.durationStandard`; respect `accessibilityReduceMotion`.

### Anti-patterns

- Letting inspector drag wider than `inspectorMaxWidth`.
- Opening inspector by default at 340pt+ on first launch.
- Resizing editor text column by dragging split (text column is **internal** padding/max-width, not a fourth split).

---

## 30-day design priorities

Aligned with [../ProductDirection.md § Next 30 days](../ProductDirection.md#6-next-30-days--frontend-first-downloads-depend-on-ui) and [FrontendPriorities.md](./FrontendPriorities.md):

1. **`OWNavigationRail`** — exit HIG sidebar ordering.
2. **Serif** fonts + **Lucide/Phosphor** icons landed in all product UI.
3. **Anytype aesthetic** density — banner, filled empty states, 36pt type rows.
4. **`LaunchIntroView`** — Bloom intro &lt; 0.5s.
5. **Filled UI checklist** P0 green; logo stays user-deferred.
6. **`OWAIPanelHeader`** + back stack; inspector collapsed default.

---

## Cross-links

| Topic | Document |
|-------|----------|
| Principles, color, motion | [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) |
| Forbidden patterns | [AntiPatterns.md](./AntiPatterns.md) |
| Chat vs inline AI | [EditorAndAIPanel.md](./EditorAndAIPanel.md) |
| Component anatomy | [Components.md](./Components.md) |

*Update when layout clamps, icon set, or font files change.*
