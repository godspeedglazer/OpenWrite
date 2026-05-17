# OpenWrite Typography

**Version:** 2.0  
**Implementation:** `OpenWrite/Design/OWTypography.swift` · **Aliases:** `DesignTokens.Typography` · **Fonts:** `OpenWrite/Resources/Fonts/`

OpenWrite uses a **Serifa-class punchy serif** for product chrome and long-form writing—not San Francisco. **ITC Serifa** is the design intent; the shipped build bundles **Source Serif 4** (SIL Open Font License 1.1) because Serifa is proprietary. SF Symbols and monospaced code blocks intentionally stay on system fonts.

---

## Design intent: ITC Serifa → Source Serif 4

| Option | Decision |
|--------|----------|
| **ITC Serifa** | **Design target** — sturdy transitional serif with strong presence at display sizes; familiar “serious writing tool” tone. |
| **Source Serif 4** (bundled `.ttf`) | **Shipped fallback** — OFL-licensed, Adobe/Google-maintained; close enough in weight and contrast for UI + body; no licensing friction. |
| **Literata** | Documented alternate if we retune for softer text (Google Fonts OFL). |
| **Inter / San Francisco** | **Removed** — reads as generic macOS utility, not a distinctive writing product. |

**Weights shipped:** Regular, Semibold, Bold (static instances). There is no separate Medium file in Source Serif 4 static cuts—`medium` tokens map to **Semibold** at the same optical size.

**Registration:** `Resources/Info.plist` → `UIAppFonts` lists each `.ttf` so macOS registers faces at launch (copied into `Contents/Resources/`).

**License:** `OpenWrite/Resources/Fonts/LICENSE.txt` (from [source-serif 4.005R](https://github.com/adobe-fonts/source-serif/releases/tag/4.005R)).

---

## Roles (`OWTypography.Role`)

| Role | Use | Typical tokens |
|------|-----|----------------|
| **display** | Page titles, NDL headings, hero copy | `documentTitle`, `heading1`–`heading3` |
| **ui** | Sidebar, shell, tabs, metadata, chips | `sidebarItem`, `sidebarSection`, `caption`, `bodyEmphasis` |
| **body** | Editor paragraphs, preview body | `body`, `editorNSFont` |

All roles use the same family; roles document *where* type appears so we can tune weight or size per surface later without scattering `Font.custom` calls.

---

## PostScript names (Swift `Font.custom`)

| Token weight | PostScript name |
|--------------|-----------------|
| Regular | `SourceSerif4-Regular` |
| Medium / Semibold | `SourceSerif4-Semibold` |
| Bold | `SourceSerif4-Bold` |

---

## Scale (`OWTypography` / `DesignTokens.Typography`)

Built with `Font.custom(_:size:relativeTo:)` and the macOS default size for each `Font.TextStyle`, so **Dynamic Type** scales with user settings.

| Token | Role | Face | Text style | Typical use |
|-------|------|------|------------|-------------|
| `documentTitle` | display | Bold | `.largeTitle` | Note title, page banner |
| `heading1` | display | Semibold | `.title` | NDL h1, preview |
| `heading2` | display | Semibold | `.title2` | NDL h2 |
| `heading3` | display | Semibold | `.title3` | NDL h3 |
| `body` | body | Regular | `.body` | Editor, paragraphs |
| `bodyEmphasis` | ui | Semibold | `.body` | Shell labels, CTAs |
| `callout` | ui | Regular | `.callout` | Subtitles, inspector |
| `caption` | ui | Regular | `.caption` | Metadata, status |
| `captionEmphasis` | ui | Semibold | `.caption` | Badges, tab labels |
| `footnote` | ui | Regular | `.footnote` | Legal, version |
| `sidebarItem` | ui | Regular | `.body` | Nav row title |
| `sidebarItemEmphasis` | ui | Semibold | `.body` | Selected / primary nav |
| `sidebarSection` | ui | Semibold | `.caption` | Section labels |
| `railSectionLabel` | ui | Semibold | `.caption2` | Navigation rail caps |
| `railSectionTracking` | — | — | — | Letter-spacing for rail caps (1.1) |
| `toolbarLabel` | ui | Regular | `.callout` | Toolbar text |
| `pageTypeIcon` | ui | Semibold | `.title3` | Type well label |
| `sidebarWellIcon` | ui | Semibold | `.caption2` | Sidebar well glyph |

### Monospace (system)

| Token | Font | Use |
|-------|------|-----|
| `code` | SF Mono via `.system(.body, design: .monospaced)` | Code blocks |
| `codeSmall` | SF Mono via `.system(.callout, design: .monospaced)` | IDs, scores |

AppKit editor (`SelectablePlainTextEditor`) uses `OWTypography.editorNSFont` (`SourceSerif4-Regular` at body size).

---

## Surfaces wired to roles

- **Shell:** `AnytypeShellView` (tabs, empty state CTA) · `OWNavigationRail`
- **Components:** `OWPageHero`, `OWPageBanner`, `OWSidebarRow`, chips
- **Editor:** `EditorView` (body, action bar) · `OWPreviewBlockRow` via tokens
- **Tokens:** `DesignTokens.Typography` forwards to `OWTypography` for the rest of the app

Prefer `OWTypography` in new shell/editor components; use `DesignTokens.Typography` when you only need the token name without naming a role.

Do not call `Font.body` or `Font.largeTitle` directly except for SF Symbols or monospaced code.

---

## Adding or changing fonts

1. Drop licensed `.ttf` / `.otf` under `OpenWrite/Resources/Fonts/`.
2. Add the file to the Xcode target **Copy Bundle Resources**.
3. List the filename in `Resources/Info.plist` under `UIAppFonts`.
4. Confirm PostScript name (Font Book or `fontTools`).
5. Update `OWTypography.Family` and token definitions.
6. Update this document and [Tokens.md](./Tokens.md).

---

*See also: [Tokens.md](./Tokens.md) · [OWComponents.md](./OWComponents.md) · [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md)*
