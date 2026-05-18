# OpenWrite Visual Themes

**Version:** 1.2  
**Implementation:** `OpenWrite/Core/Theme/` · **Picker:** `OpenWrite/UI/Settings/ThemePickerView.swift`

OpenWrite ships **thirteen** clean-room palettes inspired by the *feel* of other knowledge tools (Anytype’s calm object chrome, Reor’s dark assist rail, Logseq’s green outliner shell, MassCode’s mono editor, Solarized warmth, plus Lavender Mist, Parchment Studio, Nord Frost, Ember Dusk). We do **not** copy assets, CSS, or trademarked branding from those products.

---

## How themes work

| Piece | Role |
|-------|------|
| `ThemeID` | Stable enum stored in `UserDefaults` (`com.openwrite.selectedThemeID`) |
| `ThemePalette` | Semantic colors: sidebar, workbench chrome, editor canvas, surfaces, text, accent, borders |
| `ThemeManager` | `@Observable` singleton; `select(_:)` / `selectNext()` update persistence |
| `DesignTokens.Color` | Reads `ThemeManager.shared.palette` so existing views stay on token names |
| `Environment(\.openWritePalette)` | Direct palette access for components that need the active palette |
| `ThemePickerView` | Grid preview in **Settings** (gear sheet) and **OpenWrite → Settings** |
| `ThemeQuickToggle` | Cycle + menu in the gear sheet; **sparkles** button in the sidebar cycles themes |

Theme changes are debounced in `ThemeManager.select(_:)` (200ms quiet period), then bump `ThemeManager.revision` and post `openWriteThemeDidChange`. SwiftUI token consumers update through `openWritePalette`; AppKit-backed surfaces update only when their bridge reads revision/notification hooks. Avoid adding broad `.id(themeManager.revision)` resets on `ChatPanelView` or `EditorView`.

Legacy persisted IDs `reorDark` and `logseqGreen` map to `reorSlate` and `logseqInk` on launch.

---

## Theme catalog

| `ThemeID` | Name | Mood |
|-----------|------|------|
| `openWriteLight` | OpenWrite Light | Default bright workbench; cool gray sidebar, white editor card, blue accent |
| `openWriteDark` | OpenWrite Dark | Neutral dark surfaces; same blue accent family for evening sessions |
| `anytypeCalm` | Anytype Calm | Warm paper canvas, oatmeal sidebar, restrained blue links |
| `reorSlate` | Reor Slate | Deep blue-gray shell, violet assist highlights |
| `logseqInk` | Logseq Ink | Forest-tinted dark chrome, emerald wikilinks |
| `massCodeMono` | MassCode Mono | Near-monochrome editor dark with amber highlights |
| `midnight` | Midnight | Ink-blue night mode with cyan highlights |
| `solarizedWarm` | Solarized Warm | Cream Solarized base3 canvas, warm orange accent |
| `highContrast` | High Contrast | Black on white, heavy borders; system chrome stays light |
| `lavenderMist` | Lavender Mist | Soft lilac rail with muted violet accents |
| `parchmentStudio` | Parchment Studio | Warm editorial paper with terracotta highlights |
| `nordFrost` | Nord Frost | Cool polar night with ice-blue links |
| `emberDusk` | Ember Dusk | Smoky plum canvas with ember orange accents |

**Count check (code):** `ThemeID.allCases.count == 13`.

---

## Token mapping

Each `ThemePalette` supplies the same semantic keys consumed by `DesignTokens.Color`:

| Palette field | Typical use |
|---------------|-------------|
| `background` | Window / split root behind columns |
| `sidebarBackground` | Left navigation rail |
| `workbenchChrome` | Padding behind elevated editor card |
| `editorCanvas` | Main writing surface |
| `surface` / `surfaceElevated` | Inspector, OW Rect fills |
| `selectionPill` | Selected sidebar row |
| `textPrimary` / `textSecondary` / `textTertiary` | Type hierarchy |
| `accent` | Links, primary buttons, graph focus |
| `borderSubtle` / `borderHairline` | Cards, columns |

Derived: `accentMuted`, `wikilink`, `graphNode`, etc. — see `ThemePalette.swift`.

Shell views apply `DesignTokens.Color.background` on the split root; sidebar and workbench use their dedicated tokens.

---

## Adding a theme

1. Add a `ThemeID` case and `displayName` / `shortDescription`.
2. Define a static palette in `ThemePalette.palette(for:)`.
3. Set `prefersDarkAppearance` if system chrome should follow dark aqua.
4. Document the mood here (one short paragraph + inspiration note).
5. Confirm contrast for `textPrimary` on `editorCanvas` and `sidebarBackground`.

---

## Shipped vs planned

| Area | Shipped | Planned / caveat |
|------|---------|------------------|
| **Theme inventory** | 13 palettes with persisted `ThemeID` and legacy ID remap | Additional palettes only when semantic contrast passes |
| **Propagation model** | Debounced selection + revision + notification broadcast | Some AppKit bridges still require explicit refresh plumbing |
| **Window chrome** | `OWWindowChrome` applies palette to titlebar and frame | Alignment/vibrancy edge QA across all macOS window states |
| **Quick switching** | Sidebar cycle + Settings picker are both live | No accidental state resets during rapid theme cycling |

---

## Contributor verification checklist

1. Cycle all 13 themes from sidebar and Settings picker.
2. Confirm editor canvas, assist strip, rail, and titlebar all update in one pass.
3. Open chat and editor after switching; ensure no transcript or editor state reset.
4. Verify AppKit-backed text inputs pick up palette/selection colors after each switch.
5. Check narrow, normal, and fullscreen window widths for titlebar/chrome consistency.

---

## Related docs

- [Tokens.md](./Tokens.md) — spacing, typography, layout (theme-independent)
- [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) — product visual principles
- [AnytypeUIInspiration.md](./AnytypeUIInspiration.md) — layout patterns (not colors)
