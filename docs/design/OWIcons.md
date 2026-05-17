# OWIcons — OpenWrite icon system

OpenWrite does **not** use [SF Symbols](https://developer.apple.com/sf-symbols/) or `Image(systemName:)` in app UI. Icons are drawn with the in-house **`OWIcon`** vocabulary: hand-authored Swift `Path` strokes in a 24×24 unit space, visually aligned with **[Lucide](https://lucide.dev)** (MIT).

**Phosphor Icons** ([MIT](https://github.com/phosphor-icons/core/blob/main/LICENSE)) is an acceptable alternative when adding new glyphs; prefer Lucide for consistency with the current catalog.

## Policy

| Do | Don't |
|----|--------|
| `OWIconView(icon: .note, size: 16)` | `Image(systemName: "doc.text")` |
| `OWLabel(title: "Refine", icon: .sparkles)` | `Label("Refine", systemImage: "sparkles")` |
| `OWEmptyState(title: "…", icon: .link)` | `ContentUnavailableView(…, systemImage: …)` |
| `pageType.owIcon` on domain types | `pageType.systemImage` string maps |

**Exceptions:** none in product UI. System controls (`ProgressView`, `Toggle`, `TextField`) remain AppKit/SwiftUI stock.

## Licenses

| Set | License | Link |
|-----|---------|------|
| **Lucide** (primary reference) | ISC/MIT-style | [lucide.dev/license](https://lucide.dev/license) · [GitHub LICENSE](https://github.com/lucide-icons/lucide/blob/main/LICENSE) |
| **Phosphor** (optional alternate) | MIT | [phosphor-icons/core LICENSE](https://github.com/phosphor-icons/core/blob/main/LICENSE) |
| **SF Symbols** | Apple — **not used** in OpenWrite UI | — |

Glyphs are **reimplemented** as Swift paths (not embedded SVG assets) so stroke weight, caps, and tint stay under `DesignTokens`. When porting from Lucide/Phosphor SVGs, keep the 24×24 viewBox; slight asymmetry and round joins are OK.

## Source of truth

- **Swift:** `OpenWrite/OpenWrite/UI/Design/OWIcon.swift`
  - `enum OWIcon` — named glyphs
  - `OWIconShape` — 24×24 unit-space `Path` strokes
  - `OWIconView` — sized, colored rendering (stroke vs fill)
  - `OWLabel`, `OWEmptyState` — composed patterns
- **Domain mapping:** `PageType.owIcon`, `SidebarSection.owIcon`, `CenterWorkbenchTab.owIcon`, `InspectorTab.owIcon`, `StructureTemplate.owIcon`
- **Reserved assets:** `Assets.xcassets/OWIcons/` for PDF vectors only when a glyph is too complex for paths

## Visual language

- **Stroke weight:** ~9% of icon size, round caps/joins
- **Style:** thin geometric outlines (Lucide-like); nodes, folders, links, sparkles for AI
- **Color:** semantic `DesignTokens` / `ObjectType.accent` — icons are not multicolor SF hierarchical renders
- **Filled variants:** only where needed (`.statusDot`, `.starFilled`, `.warningFill`, `.micActive`, `.checkmarkCircle`)

## Lucide name map (representative)

| `OWIcon` | Lucide name |
|----------|-------------|
| `note` | `file-text` |
| `task` | `circle-check` |
| `journal` | `notebook` |
| `search` | `search` |
| `settings` | `settings` |
| `graph` | `share-2` / custom nodes |
| `database` | `database` |
| `grid` | `grid-3x3` |
| `plus` | `plus` |
| `checkmark` | `check` |
| `chat` | `messages-square` |
| `sparkles` | `sparkles` |
| `send` | `circle-arrow-up` |
| `link` | `link` |
| `chevronRight` / `back` | `chevron-right` / mirrored |

## Adding an icon

1. Add a case to `OWIcon`.
2. Implement `unitPath()` in the private `OWIcon` extension (coordinates 0…24), using the Lucide/Phosphor SVG as reference.
3. Set `rendering` to `.stroke` or `.fill` if not stroke-default.
4. Use `OWIconView` in views; extend domain enums with `owIcon` when the glyph maps to a model type.
5. Document the glyph and Lucide name in this file.

## Catalog

| `OWIcon` | Use |
|----------|-----|
| `note`, `task`, `journal`, `project`, `reference`, `collection`, `book`, `document`, `wiki` | `PageType` |
| `graph`, `search`, `settings`, `lockShield`, `plus`, `database`, `grid` | Shell / vault / databases |
| `chat`, `related`, `pastWrites`, `sparkles` | AI assist strip |
| `send`, `mic`, `micActive`, `waveform` | Chat composer |
| `link`, `warning`, `warningFill` | Graph / errors |
| `chevronRight`, `chevronDown`, `back`, `forward`, `collapseTrailing` | Navigation |
| `editCompose`, `missingNote` | Empty states |
| `zoomIn`, `zoomOut`, `grid` | Graph chrome |
| `clock`, `tag`, `sliders`, `statusDot` | Metadata chips |
| `checkmark`, `checkmarkCircle`, `agent`, `star`, `starFilled` | Pickers / ratings |

## Related docs

- [OWComponents.md](OWComponents.md) — sidebar row, hero, chips (OWIcon-backed)
- [Tokens.md](Tokens.md) — color and spacing for icon alignment
- [AntiPatterns.md](AntiPatterns.md) — SF Symbols ban in product surfaces
