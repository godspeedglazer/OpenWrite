# OpenWrite Typography

**Version:** 1.0  
**Implementation:** `OpenWrite/Design/DesignTokens.swift` · **Fonts:** `OpenWrite/Resources/Fonts/`

OpenWrite uses **bundled Inter** (SIL Open Font License 1.1) instead of the macOS system UI font (San Francisco) for product chrome and editor text. SF Symbols and monospaced code blocks intentionally stay on system fonts.

---

## Choice: Inter (bundled)

| Option | Decision |
|--------|----------|
| **Inter** (bundled `.ttf`) | **Selected** — neutral, highly legible at UI sizes; distinct from default Mac apps; OFL license allows bundling. |
| Geist | Not used — similar role to Inter; kept as a documented alternative if we rebrand. |
| System alternative (e.g. `.rounded`) | Rejected for v1 — still reads as “stock macOS” and does not match the writing-product positioning. |

**Weights shipped:** Regular, Medium, SemiBold, Bold (static instances under `Resources/Fonts/`).

**Registration:** `Resources/Info.plist` lists each file under `UIAppFonts` so macOS registers the bundled faces at launch (files copy into `Contents/Resources/`).

**License:** Full OFL text in `OpenWrite/Resources/Fonts/LICENSE.txt` (from [Inter v4.1](https://github.com/rsms/inter/releases/tag/v4.1)).

---

## PostScript names (Swift `Font.custom`)

| Token weight | PostScript name |
|--------------|-----------------|
| Regular | `Inter-Regular` |
| Medium | `Inter-Medium` |
| SemiBold | `Inter-SemiBold` |
| Bold | `Inter-Bold` |

---

## Scale (`DesignTokens.Typography`)

All UI text styles are built with `Font.custom(_:size:relativeTo:)` and the macOS default size for each `Font.TextStyle`, so **Dynamic Type** (where enabled) scales with user settings.

| Token | Inter face | Text style | Typical use |
|-------|------------|------------|-------------|
| `documentTitle` | Bold | `.largeTitle` | Note title, page hero |
| `heading1` | SemiBold | `.title` | NDL h1, preview |
| `heading2` | SemiBold | `.title2` | NDL h2, section headers |
| `heading3` | Medium | `.title3` | NDL h3 |
| `body` | Regular | `.body` | Paragraphs, editor |
| `bodyEmphasis` | Medium | `.body` | Strong inline, shell labels |
| `callout` | Regular | `.callout` | Inspector, subtitles |
| `caption` | Regular | `.caption` | Metadata, status |
| `captionEmphasis` | Medium | `.caption` | Badges, chips |
| `footnote` | Regular | `.footnote` | Legal, version |
| `sidebarItem` | Regular | `.body` | Nav row title |
| `sidebarItemEmphasis` | Medium | `.body` | Selected / primary nav |
| `sidebarSection` | SemiBold | `.caption` | “VAULT”, section labels |
| `toolbarLabel` | Regular | `.callout` | Toolbar text |
| `pageTypeIcon` | Medium | `.title3` | Editor type icon |
| `sidebarWellIcon` | SemiBold | `.caption2` | Sidebar well glyph |
| `heroSymbol` | — (system) | — | Large SF Symbol in empty states |

### Monospace (system)

| Token | Font | Use |
|-------|------|-----|
| `code` | SF Mono via `.system(.body, design: .monospaced)` | Code blocks |
| `codeSmall` | SF Mono via `.system(.callout, design: .monospaced)` | IDs, scores |

AppKit editor (`SelectablePlainTextEditor`) uses `DesignTokens.Typography.editorNSFont` (`Inter-Regular` at body size).

---

## Surfaces updated in code

- **Shell:** `AnytypeShellView`, `AIAssistStripView`, `GraphPlaceholderView`
- **Components:** `OWPageHero`, `OWSidebarRow`, `OWObjectTypeChip`, `OWMetadataChip`
- **Editor:** `EditorView` (title, body, NDL preview headings)
- **Tokens:** `DesignTokens.Typography` (single source of truth)

New views should use tokens only — do not call `Font.body` or `Font.largeTitle` directly except for SF Symbols (`heroSymbol`) or monospaced code.

---

## Adding or changing fonts

1. Drop licensed `.ttf` / `.otf` under `OpenWrite/Resources/Fonts/`.
2. Add the file to the Xcode target **Copy Bundle Resources**.
3. Confirm PostScript name (e.g. with Font Book or `CGFont`).
4. Extend `DesignTokens.Typography.Family` and token definitions.
5. Update this document and [Tokens.md](./Tokens.md) typography table.

---

*See also: [Tokens.md](./Tokens.md) · [OWComponents.md](./OWComponents.md) · [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md)*
