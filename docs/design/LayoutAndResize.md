# Layout and window resize

**Version:** 1.0  
**Last updated:** 2026-05-17  
**Implementation:** `AnytypeShellView.swift`, `ContentView.swift`, `OpenWriteApp.swift`, `AppDelegate.swift`, `DesignTokens.Layout`

OpenWrite’s workbench is a three-region shell: **sidebar** (NavigationSplitView leading column), **editor workbench** (detail column), and an optional **AI assist strip** inside the detail column. Resize behavior keeps the editor as the flexible hero while side regions honor fixed minimums.

---

## Column constraints

| Region | Min width | Preferred / max | Growth behavior |
|--------|-----------|-----------------|-----------------|
| Sidebar | 220 pt | ideal 248 pt, max 280 pt | `navigationSplitViewColumnWidth`; user can drag within clamp |
| Editor workbench | 400 pt | unbounded | `layoutPriority(1)` — receives extra width when the window grows |
| AI assist strip (expanded) | 240 pt | max 320 pt | `layoutPriority(0)` — yields width before the editor when space is tight |

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

The sidebar is outside this `HStack`; its width is governed by `NavigationSplitView` column width APIs, not layout priority.

When horizontal space is insufficient, prefer collapsing assist (`WorkbenchState.aiAssistExpanded = false`) over violating editor minimums — product logic may enforce this later; v1 relies on window `minSize` and frame mins.

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
