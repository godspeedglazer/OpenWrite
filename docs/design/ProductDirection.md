# OpenWrite Design Product Direction

**Version:** 1.0  
**Last updated:** 2026-05-17  
**Audience:** Design and UI implementers  
**Product scope (full):** [../ProductDirection.md](../ProductDirection.md)  
**Visual system:** [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) · [AntiPatterns.md](./AntiPatterns.md)

This page captures **non-negotiable design direction** for the OpenWrite shell. It does not replace the master product doc; it makes explicit what “native macOS” means for OpenWrite: **platform integration without Apple HIG stock chrome or SF Symbols in product UI.**

---

## Identity: not HIG-default, not SF Symbols

| OpenWrite is | OpenWrite is not |
|--------------|------------------|
| A **custom** calm workbench (Anytype-*inspired* density, clean-room) | A settings-app built from `Form`, `List`, and SF Symbol sidebars |
| **Bundled** typography and **OWIcon** assets | San Francisco + SF Symbols as the product face |
| macOS for sandbox, Keychain, shortcuts, VoiceOver | “Looks like a first-party Apple utility” |

**SF Symbols ban:** Do not use `Image(systemName:)`, `Label(..., systemImage:)`, or SF-based `ContentUnavailableView` in vault, editor, inspector, graph, or AI surfaces. See [AntiPatterns.md](./AntiPatterns.md).

**Typography requirement:** All chrome and editor typography flows through **`DesignTokens.Typography`** backed by **bundled font files** in the app target (`Resources/Fonts/`). System font is permitted only for user-authored content previews where NDL does not specify a face, and for controls AppKit renders exclusively (documented exceptions).

---

## Required primitives

| Primitive | Role |
|-----------|------|
| **`OWIcon`** | Single icon pipeline — template PDF/SVG, `accent` / `textSecondary` / object-type tints |
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

Aligned with [../ProductDirection.md § Next 30 days](../ProductDirection.md#6-next-30-days--ui-priorities):

1. Replace SF Symbol usage with **`OWIcon`** catalog.
2. Register **bundled fonts** and point `DesignTokens.Typography` at them.
3. **`OWAIPanelHeader`** + back stack in chat/agent flows.
4. Enforce **resize clamps** and inspector collapsed default.
5. Wire **`OWSidebarRow`** vault list; remove LM Studio block from rail.

---

## Cross-links

| Topic | Document |
|-------|----------|
| Principles, color, motion | [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) |
| Forbidden patterns | [AntiPatterns.md](./AntiPatterns.md) |
| Chat vs inline AI | [EditorAndAIPanel.md](./EditorAndAIPanel.md) |
| Component anatomy | [Components.md](./Components.md) |

*Update when layout clamps, icon set, or font files change.*
