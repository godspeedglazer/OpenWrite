# OWIcons — OpenWrite icon system

OpenWrite does **not** use [SF Symbols](https://developer.apple.com/sf-symbols/) or `Image(systemName:)` in app UI. Product surfaces render **Unicode and open characters** through **`OWUnicodeIcon`** — fixed-size `Text` glyphs, not custom `Path` strokes and not the SF Symbols catalog.

**Legacy:** `OWIcon` / `OWIconView` / `OWIconShape` remain in the tree for migration reference but are **deprecated** in product UI. Do not add new `OWIconView` call sites.

## Policy

| Do | Don't |
|----|--------|
| `OWUnicodeIconView(pageType: .reference, size: 16)` | `Image(systemName: "link")` |
| `OWUnicodeIconView(icon: .settings, size: 16)` | `OWIconView` / `OWIconShape` in product UI |
| `pageType.unicodeCharacter` / `pageType.unicodeIcon` | Lucide/Phosphor SVG assets unless explicitly revived |
| `OWLabel(title: "Refine", icon: .sparkles)` (unicode-backed) | `Label("Refine", systemImage: "sparkles")` |

**Exceptions:** none in product UI. System controls (`ProgressView`, `Toggle`, `TextField`) remain AppKit/SwiftUI stock.

## Source of truth

- **Swift (primary):** `OpenWrite/OpenWrite/UI/Design/OWUnicodeIcon.swift`
  - `enum OWUnicodeIcon` — named glyphs → single-character strings
  - `OWUnicodeIconView` — sized `Text` rendering with semantic tint
  - `OWUnicodePageTypeIconWell` — tinted well for sidebar / banner density
  - Domain: `PageType.unicodeIcon`, `OWIcon.unicodeCharacter`, `SidebarSection.unicodeIcon`, …
- **Swift (deprecated):** `OpenWrite/OpenWrite/UI/Design/OWIcon.swift` — path-drawn Lucide-style shapes; keep for reference only

## Glyph map (representative)

| Semantic | Character | Notes |
|----------|-----------|--------|
| Note | 📝 | Plain note; alternate ◻ acceptable for minimal themes |
| Task | ✓ | |
| Journal | 📓 | |
| Project | 📁 | |
| Reference | 🔗 | **Required** — do not use broken path reference glyph |
| Collection | ⊞ | |
| Graph | ◉ | |
| Search | ⌕ | |
| Settings | ⚙ | |
| Back | ← | |
| Chat | 💬 | |
| Wiki | ⌁ | Open “site” mark |
| Database | ⊟ | |
| AI / sparkles | ✦ | |

## Visual language

- **Rendering:** `Text` at a fixed frame (`OWUnicodeIconView`); font size ≈ 72% of frame edge
- **Color:** semantic `DesignTokens` / `ObjectType.accent` — glyphs are monochrome via `foregroundStyle`
- **Wells:** `OWUnicodePageTypeIconWell` — rounded rect + object-type background (sidebar, banner)

## Adding an icon

1. Add a case to `OWUnicodeIcon` with `character` and `accessibilityLabel`.
2. If bridging from `OWIcon`, add matching `rawValue` on `OWIcon` or map in `OWIcon.unicodeIcon`.
3. Use `OWUnicodeIconView` in views; extend domain enums with `unicodeIcon` when the glyph maps to a model type.
4. Document the character in this file.

## Related docs

- [OWComponents.md](OWComponents.md) — sidebar row, hero, chips (unicode-backed)
- [Tokens.md](Tokens.md) — color and spacing for icon alignment
- [AntiPatterns.md](AntiPatterns.md) — SF Symbols ban in product surfaces
