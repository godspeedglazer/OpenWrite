# OWIcons — OpenWrite icon system

OpenWrite does **not** use [SF Symbols](https://developer.apple.com/sf-symbols/) or `Image(systemName:)` in app UI. Icons are drawn with the in-house `OWIcon` vocabulary so the workbench has a consistent, Anytype-like geometric stroke language that we own end-to-end.

## Policy

| Do | Don't |
|----|--------|
| `OWIconView(icon: .note, size: 16)` | `Image(systemName: "doc.text")` |
| `OWLabel(title: "Refine", icon: .sparkles)` | `Label("Refine", systemImage: "sparkles")` |
| `OWEmptyState(title: "…", icon: .link)` | `ContentUnavailableView(…, systemImage: …)` |
| `pageType.owIcon` on domain types | `pageType.systemImage` string maps |

Exceptions: none in product UI. System controls (`ProgressView`, `Toggle`, `TextField`) remain AppKit/SwiftUI stock.

## Source of truth

- **Swift:** `OpenWrite/OpenWrite/UI/Design/OWIcon.swift`
  - `enum OWIcon` — named glyphs
  - `OWIconShape` — 24×24 unit-space `Path` strokes
  - `OWIconView` — sized, colored rendering (stroke vs fill)
  - `OWLabel`, `OWEmptyState` — composed patterns
- **Domain mapping:** `PageType.owIcon`, `SidebarSection.owIcon`, `CenterWorkbenchTab.owIcon`, `InspectorTab.owIcon`, `StructureTemplate.owIcon`

## Visual language

- **Stroke weight:** ~9% of icon size, round caps/joins
- **Style:** thin geometric outlines (nodes, folders, links, sparkles for AI)
- **Color:** semantic `DesignTokens` / `ObjectType.accent` — icons are not multicolor SF hierarchical renders
- **Filled variants:** only where needed (`.statusDot`, `.starFilled`, `.warningFill`, `.micActive`, `.checkmarkCircle`)

## Adding an icon

1. Add a case to `OWIcon`.
2. Implement `unitPath()` in the private `OWIcon` extension (coordinates 0…24).
3. Set `rendering` to `.stroke` or `.fill` if not stroke-default.
4. Use `OWIconView` in views; extend domain enums with `owIcon` when the glyph maps to a model type.
5. Document the glyph name here.

## Optional PDF assets

`Assets.xcassets/OWIcons/` is reserved for PDF vectors if a glyph is too complex for hand-authored paths. Prefer paths first; PDFs must match stroke weight and corner radius of path icons.

## Catalog (initial set)

| `OWIcon` | Use |
|----------|-----|
| `note`, `task`, `journal`, `project`, `reference`, `collection`, `book`, `document`, `wiki` | `PageType` |
| `graph`, `search`, `settings`, `lockShield`, `plus` | Shell / vault |
| `chat`, `related`, `pastWrites`, `sparkles` | AI assist strip |
| `send`, `mic`, `micActive`, `waveform` | Chat composer |
| `link`, `warning`, `warningFill` | Graph / errors |
| `chevronRight`, `chevronDown`, `back`, `forward`, `collapseTrailing` | Navigation |
| `editCompose`, `missingNote` | Empty states |
| `zoomIn`, `zoomOut`, `grid` | Graph chrome |
| `clock`, `tag`, `sliders`, `statusDot` | Metadata chips |
| `checkmark`, `checkmarkCircle`, `agent`, `star`, `starFilled` | Pickers / ratings |

## Related docs

- [OWComponents.md](OWComponents.md) — sidebar row, hero, chips (now OWIcon-backed)
- [Tokens.md](Tokens.md) — color and spacing for icon alignment
