# Sidebar philosophy (anti-HIG)

OpenWrite’s leading column is a **navigation rail**, not an Apple Settings-style sidebar. We use column geometry when helpful, but we refuse the visual and interaction vocabulary that makes macOS apps feel interchangeable.

## What we reject

| Apple / HIG pattern | Why we avoid it |
|---------------------|-----------------|
| `NavigationSplitView` **sidebar column** with `List` + `.listStyle(.sidebar)` | System selection blue, disclosure chevrons, vibrancy materials |
| `NSSearchField` / `.searchable` in the sidebar | Rounded glass search capsule reads as “built-in Mac app” |
| SF Symbols in vault chrome (`lock.shield`, folder badges) | Platform glyph = instant HIG recognition |
| Resizable sidebar drag handle as the primary nav metaphor | Encourages “Finder width tuning” instead of a fixed object rail |
| Section headers in **Inter semibold** matching the rest of the UI | Same voice as body copy; no editorial hierarchy |

## What we build instead

**`OWNavigationRail`** (`UI/Shell/OWNavigationRail.swift`):

- **Fixed width** — `DesignTokens.Layout.navigationRailWidth` (248pt); not user-resizable.
- **Custom background** — flat `sidebarBackground` + subtle diagonal wash; hairline trailing edge, not sidebar material.
- **No `List` selection** — rows are `OWSidebarRow` buttons with pill hover/selection; never `List` row backgrounds.
- **Section labels** — `OWNavigationRailSectionLabel`: **small caps**, **serif** (`Typography.railSectionLabel`), tracked caps for OBJECTS / DATABASES / VAULT.
- **Search** — `OWRailSearchField`: plain `TextField`, OW magnifier, flat surface + hairline border; focus ring via accent stroke, not `NSSearchField`.
- **Brand mark** — `OWPageTypeIconWell` + `.notes` (custom stroke icon), not shield / lock metaphors.

**Shell wiring** — `AnytypeShellView` composes `HStack { OWNavigationRail, centerWorkbench }`. We do **not** put vault navigation inside `NavigationSplitView`’s leading column. Split views may return later for inspector geometry only; the rail stays custom.

## Resize and collapse

Rail visibility follows `WorkbenchState.sidebarVisible` (e.g. `Cmd+Ctrl+S`). When hidden, the center workbench expands; clamps in [LayoutAndResize.md](./LayoutAndResize.md) still apply to editor + assist strip.

## Related docs

- [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) — workbench zones and deliberate avoids
- [OWComponents.md](./OWComponents.md) — `OWSidebarRow`, `OWRoundedRect`
- [LayoutAndResize.md](./LayoutAndResize.md) — window breakpoints
