# OpenWrite OW Components

**Version:** 2.1  
**Implementation:** `OpenWrite/UI/Design/*.swift`  
**Tokens:** [Tokens.md](./Tokens.md) · **Language:** [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) · **Bans:** [AntiPatterns.md](./AntiPatterns.md)

Reusable SwiftUI primitives for the **custom** OpenWrite shell (not default `List` / `.sidebar` chrome, **not SF Symbols**). All components compose **`OWRoundedRect`** for surfaces, **`OWIcon`** for glyphs, and read **`DesignTokens`** only.

---

## OWIcon

**Purpose:** Canonical icon renderer — **the only** icon pipeline for product UI. Replaces all `Image(systemName:)` / `Label(..., systemImage:)` usage.

| Prop | Value |
|------|-------|
| Asset | Template PDF/SVG in `OWIcons` asset catalog |
| Sizes | `16` · `18` · `20` · `48` pt frames (sidebar, toolbar, inspector, hero) |
| Tint | `foregroundStyle` from `textPrimary`, `textSecondary`, `accent`, or `ObjectType.accent(for:)` |
| Accessibility | `accessibilityLabel` required; decorative icons hidden from VO |

**Catalog (stable names)**

| Name | Use |
|------|-----|
| `notes` | Notes section, document rows |
| `graph` | Graph section |
| `search` | Search section |
| `ai` | AI section / assist |
| `publish` | Publish section |
| `capture` | Quick capture |
| `lock` | Vault locked |
| `chevronLeft` | AI panel back |
| `link` | Wikilinks, graph edges |
| `tag` | Tags metadata |
| `warning` | Errors (non-destructive) |

**Swift API**

```swift
OWIcon(.notes, size: .sidebar, tint: .secondary)
OWIcon(.graph, size: .hero, tint: .accent)
```

**Do not** reference SF Symbol names in views. **Do not** mix emoji into nav icons (emoji remain on `OWPageHero` page icons only).

---

## OWRoundedRect

**Purpose:** Canonical rounded rectangle surface — the “OW Rect” building block for cards, inspector panels, capture fields, and bordered regions.

| Prop | Token / value |
|------|----------------|
| Corner radius | `DesignTokens.Radius.owRect` (11pt; range 10–12) |
| Fill | `surface`, `surfaceElevated`, `editorCanvas`, or `clear` |
| Border | Optional 1px `borderSubtle` |
| Padding | Caller-defined; default inset `spacing3` when used as container |

**Variants**

| Variant | Fill | Border | Shadow |
|---------|------|--------|--------|
| `surface` | `Color.surface` | none | none |
| `elevated` | `Color.surfaceElevated` | `borderSubtle` | `Shadow.subtle` |
| `editorPanel` | `Color.editorCanvas` | `borderSubtle` | none |
| `sidebarCard` | `Color.surfaceElevated` on `sidebarBackground` | `borderSubtle` | none |

**Swift API**

```swift
OWRoundedRect(style: OWRoundedRectStyle.elevated) {
    VStack { ... }
}

// Modifier on arbitrary content:
content.owRect(style: .surface, padding: DesignTokens.Spacing.spacing4)
```

**Do not** use for full-window backgrounds or pill selection chips (use `Radius.pill` via `OWSidebarRow` / `OWObjectTypeChip`).

---

## OWSidebarRow

**Purpose:** Object list row in the left rail — calm density, pill selection on gray sidebar.

| Prop | Value |
|------|-------|
| Row height | `Layout.sidebarRowHeight` (38pt; target 36–40) |
| Horizontal inset | `spacing2` from sidebar edge |
| Icon | `OWIcon`, 18pt frame (`sidebarRowIconSize`), tinted with object-type accent when `pageType` set |
| Title | `Typography.sidebarItem`, `textPrimary` |
| Subtitle | `Typography.caption`, `textSecondary`, one line |
| Selection | White / elevated pill (`selectionPill`) + optional `borderSubtle`; animated `Motion.animationFast` |
| Hover | `Opacity.overlayLight` on unselected rows |
| Press | `Opacity.overlayMedium` |

**Interaction:** Plain button; VoiceOver: “{title}, {type}, {selected}”.

**Usage**

```swift
OWSidebarRow(
    title: doc.displayTitle,
    subtitle: doc.pageType.displayName,
    icon: doc.pageType.owIcon,
    pageType: doc.pageType,
    isSelected: selectedID == doc.id
) {
    selectedID = doc.id
}
```

---

## OWObjectTypeChip

**Purpose:** Compact type label (sidebar meta, editor header, pickers) — colored pill distinct from nav selection.

| Prop | Value |
|------|-------|
| Height | 24pt min |
| Radius | `Radius.pill` |
| Typography | `Typography.captionEmphasis` |
| Fill | `ObjectType.accent(for:)` @ 14% opacity |
| Foreground | `ObjectType.accent(for:)` |
| Icon | Optional leading `OWIcon` (16pt) |

Maps `PageType` → `DesignTokens.ObjectType` accents (not system `Color.blue`).

**Usage**

```swift
OWObjectTypeChip(pageType: .task)
OWObjectTypeChip(pageType: .note, showsIcon: true)
```

---

## OWPageHero

**Purpose:** Top-of-column hero for empty states, welcome, and document title blocks in the **white editor canvas**.

| Prop | Value |
|------|-------|
| Max width | `Layout.editorMaxContentWidth`, centered |
| Title | `Typography.documentTitle` |
| Subtitle | `Typography.callout`, `textSecondary` |
| Icon | 48pt `OWIcon`, `accent` or object-type accent |
| Vertical spacing | `spacing6` below icon, `spacing3` title → subtitle |
| Outer padding | `editorPadding` |

**Variants**

| Variant | Use |
|---------|-----|
| `.emptyState` | `ContentUnavailableView` replacement styling |
| `.documentHeader` | Title + type chip row above editor body |

**Usage**

```swift
OWPageHero(
    title: "Select a note",
    subtitle: "Encrypted local notes with typed pages.",
    icon: .notes,
    style: .emptyState
)
```

---

## OWAIPanelHeader

**Purpose:** Inspector AI chrome — title, **back** when navigation depth ≥ 1, trailing actions (agent picker, clear thread).

| Prop | Value |
|------|-------|
| Height | `toolbarHeight` (52pt) or compact 44pt in nested stacks |
| Leading | `OWIcon(.chevronLeft)` back button when `canGoBack`; hidden at depth 0 |
| Title | `Typography.callout` or `bodyEmphasis`, `textPrimary`, one line |
| Trailing | `OWIconButton` cluster (settings, new chat) |
| Separator | Optional 1px `borderSubtle` bottom |

**Interaction:** Back pops local navigation path ([ProductDirection.md § AI panels](./ProductDirection.md#ai-panels-back-navigation)); `Escape` / `Cmd+[` when inspector focused.

**Usage**

```swift
OWAIPanelHeader(
    title: "Agent settings",
    canGoBack: true,
    onBack: { path.pop() }
) {
    AgentPickerMenu(...)
}
```

---

## Composition map

```
Sidebar (sidebarBackground)
├── OWSidebarRow × N
└── OWObjectTypeChip (inline in row subtitle optional)

Inspector (background)
├── OWAIPanelHeader → Chat / Related / Past Writes + back stack
└── OWRoundedRect.elevated → panel bodies (not grouped Form)

Editor (editorCanvas)
├── OWPageHero.documentHeader
├── OWObjectTypeChip
└── OWRoundedRect.editorPanel → properties strip
```

---

## Changelog

| Version | Change |
|---------|--------|
| 2.1 | `OWIcon`, `OWAIPanelHeader`; SF Symbols ban; bundled typography note |
| 2.0 | Initial OW component specs (Anytype-inspired custom chrome) |

---

*See also: [Components.md](./Components.md) (workbench-level patterns)*
