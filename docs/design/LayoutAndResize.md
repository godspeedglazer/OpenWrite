# Layout and window resize

**Version:** 1.0  
**Last updated:** 2026-05-17  
**Implementation:** `AnytypeShellView.swift`, `ContentView.swift`, `OpenWriteApp.swift`, `AppDelegate.swift`, `DesignTokens.Layout`

OpenWrite’s workbench is a three-region shell: **navigation rail** (`OWNavigationRail`, optional/resizable), **editor workbench** (center `OWRoundedRect` card), and an optional **AI assist strip** inside the center column (`OWResizableColumnSplit`). Resize behavior keeps the editor as the flexible hero while side regions honor fixed minimums.

---

## Column constraints

| Region | Min width | Preferred / max | Growth behavior |
|--------|-----------|-----------------|-----------------|
| Navigation rail | 220 pt | user preference, max 280 pt | `OWResizableColumnSplit` leading column in `AnytypeShellView` |
| Editor workbench | 400 pt (lower when assist open) | readable column max 880 pt inside card | `layoutPriority(1)`; `openWriteEditorContentWidth()` centers body |
| AI assist strip (expanded) | 240 pt | max 360 pt (`assistStripMaxWidth`) | `layoutPriority(0)` trailing fixed column |

Tokens live in `DesignTokens.Layout` (`sidebarMinWidth`, `editorMinWidth`, `assistStripMinWidth`, etc.).

---

## Window sizing

| Property | Value | Where applied |
|----------|-------|----------------|
| Default size | 1200 × 800 | `WindowGroup.defaultSize` in `OpenWriteApp` |
| Minimum size | 900 × 600 | `ContentView.frame(minWidth:minHeight:)` + `NSWindow.minSize` in `AppDelegate.applyWindowSizingPolicy` |

Minimum window width (900 pt) is slightly above the sum of region minimums (220 + 400 + 240 = 860 pt) plus split chrome and `centerCardOuterPadding`, so all three regions can remain visible with assist expanded.

---

## Layout priority

Inside `AnytypeShellView.centerWorkbench`:

1. **Editor column** — `layoutPriority(1)` and `frame(minWidth: editorMinWidth)`. SwiftUI offers surplus horizontal space here first.
2. **Assist strip** — `layoutPriority(0)` with `frame(minWidth:maxWidth:)` on `assistStripMinWidth` / `assistStripMaxWidth`. Shrinks only down to 240 pt; does not grow past 320 pt.

The navigation rail is a sibling split outside the center `GeometryReader`; width is stored in `ShellChromePreferences.navigationRailWidth`.

When horizontal space is insufficient, `OWShellLayout.shouldAutoCollapseAssist` collapses assist (`WorkbenchState.aiAssistExpanded = false`) before violating `editorMinWidthWhenAssistOpen`. Editor scroll remeasures via `editorScrollLayoutToken` when assist or rail visibility changes (`OpenWriteThemedScrollView`).

---

## Files

| File | Role |
|------|------|
| `UI/Shell/AnytypeShellView.swift` | Split view column width; editor vs assist `HStack` |
| `UI/ContentView.swift` | Root `frame(minWidth:minHeight:)` for window content |
| `App/OpenWriteApp.swift` | `defaultSize` |
| `App/AppDelegate.swift` | `NSWindow.minSize` on main window presentation |
| `Design/DesignTokens.swift` | All numeric constants |

See also [Tokens.md](./Tokens.md) for the full layout token table and [EditorAndAIPanel.md](./EditorAndAIPanel.md) for assist strip UX.
