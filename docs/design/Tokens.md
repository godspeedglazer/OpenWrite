# OpenWrite Design Tokens

**Version:** 1.0  
**Implementation:** `OpenWrite/Design/DesignTokens.swift`  
**Grid:** 4pt base unit

All UI code should reference **`DesignTokens`** (or SwiftUI extensions backed by it), not magic numbers. Token names are stable API; values may shift in patch releases for contrast fixes.

---

## Table of contents

1. [Naming convention](#naming-convention)
2. [Color](#color)
3. [Typography](#typography)
4. [Spacing](#spacing)
5. [Radius](#radius)
6. [Shadow](#shadow)
7. [Motion](#motion-cross-reference)
8. [Layout constants](#layout-constants)
9. [SwiftUI usage examples](#swiftui-usage-examples)
10. [Asset catalog](#asset-catalog)

---

## Naming convention

```
DesignTokens.<Category>.<name>
```

| Category | Swift enum | Example |
|----------|------------|---------|
| Color | `DesignTokens.Color` | `.background` |
| Typography | `DesignTokens.Typography` | `.documentTitle` |
| Spacing | `DesignTokens.Spacing` | `.spacing4` |
| Radius | `DesignTokens.Radius` | `.medium` |
| Shadow | `DesignTokens.Shadow` | `.floating` |
| Motion | `DesignTokens.Motion` | `.durationStandard` |
| Layout | `DesignTokens.Layout` | `.sidebarMinWidth` |

---

## Color

Semantic colors adapt to `ColorScheme` via static computed `Color` properties.

### Palette reference (light appearance)

| Token | Role | Light (sRGB) | Dark (sRGB) |
|-------|------|--------------|-------------|
| `background` | Window / split background | 0.98, 0.98, 0.97 | 0.11, 0.11, 0.12 |
| `surface` | Sidebar, inspector, code bg | 0.95, 0.95, 0.94 | 0.15, 0.15, 0.16 |
| `surfaceElevated` | Sheets, popovers | 1.0, 1.0, 1.0 | 0.18, 0.18, 0.19 |
| `textPrimary` | Headings, body | 0.10, 0.10, 0.10 | 0.95, 0.95, 0.96 |
| `textSecondary` | Metadata, nav inactive | 0.45, 0.45, 0.47 | 0.62, 0.62, 0.64 |
| `textTertiary` | Placeholders, disabled | 0.60, 0.60, 0.62 | 0.48, 0.48, 0.50 |
| `accent` | Links, selection, primary | 0.23, 0.42, 0.88 | 0.35, 0.55, 0.95 |
| `accentMuted` | Hover, subtle highlight | accent @ 12% on surface | accent @ 18% on surface |
| `separator` | Dividers | 0.88, 0.88, 0.87 | 0.28, 0.28, 0.30 |
| `danger` | Errors, destructive | 0.85, 0.22, 0.24 | 0.95, 0.35, 0.38 |
| `dangerMuted` | Destructive button bg | danger @ 10% | danger @ 15% |
| `success` | Positive confirm | 0.20, 0.62, 0.38 | 0.35, 0.75, 0.50 |
| `warning` | Caution, lock reminder | 0.85, 0.55, 0.12 | 0.95, 0.70, 0.25 |
| `wikilink` | NDL wikilink blocks | same as `accent` | same as `accent` |
| `codeBackground` | Inline / block code | surface @ +3% contrast | surface @ +3% |
| `graphNode` | Default node fill | surfaceElevated | surfaceElevated |
| `graphEdge` | Edge stroke | textTertiary | textTertiary |
| `graphNodeFocused` | Selected node stroke | accent | accent |

### Swift mapping

```swift
Text("Hello")
    .foregroundStyle(DesignTokens.Color.textPrimary)

Rectangle()
    .fill(DesignTokens.Color.surface)
```

### When to use `Color.accentColor`

Use `DesignTokens.Color.accent` for **product-branded** elements (wikilinks, graph focus). Use SwiftUI `Color.accentColor` only when matching **system** controls tied to the user’s macOS accent (rare in OpenWrite v1).

### Opacity helpers

| Helper | Value | Use |
|--------|-------|-----|
| `overlayLight` | 0.04 | Hover on sidebar row |
| `overlayMedium` | 0.08 | Pressed state |
| `overlayStrong` | 0.12 | Selected row background |
| `scrim` | 0.35 | Sheet backdrop (if custom) |

Defined as `DesignTokens.Opacity.*` in code.

---

## Typography

### Scale

| Token | Font | Weight | Line spacing | Typical use |
|-------|------|--------|--------------|-------------|
| `documentTitle` | `.largeTitle` | bold | system | Note title |
| `heading1` | `.title` | semibold | system | NDL h1 |
| `heading2` | `.title2` | semibold | system | NDL h2 |
| `heading3` | `.title3` | medium | system | NDL h3 |
| `body` | `.body` | regular | system | Paragraph |
| `bodyEmphasis` | `.body` | medium | system | Strong inline |
| `callout` | `.callout` | regular | system | Inspector labels |
| `caption` | `.caption` | regular | system | Status, footnotes |
| `captionEmphasis` | `.caption` | medium | system | Badge text |
| `footnote` | `.footnote` | regular | system | Legal, version |
| `code` | `.body` monospaced | regular | system | Code blocks |
| `codeSmall` | `.callout` monospaced | regular | system | Citations, IDs |
| `sidebarItem` | `.body` | regular | system | Nav rows |
| `sidebarSection` | `.caption` | semibold | system | “VAULT”, “AI” headers |
| `toolbarLabel` | `.callout` | regular | system | Toolbar text |

### Swift mapping

```swift
Text(document.title)
    .font(DesignTokens.Typography.documentTitle)

Text(block.text)
    .font(DesignTokens.Typography.body)
```

### Dynamic Type

Editor body should use semantic fonts so **⌘+** and **⌘-** scale where AppKit/SwiftUI propagate size changes. Fixed-size fonts are allowed only in graph minimap or dense table views with horizontal scroll fallback.

---

## Spacing

Base unit: **4pt**. Token = multiplier × 4.

| Token | Points | Multiplier | Use |
|-------|--------|------------|-----|
| `spacing0` | 0 | 0 | Reset |
| `spacing1` | 4 | 1 | Tight inline, icon padding |
| `spacing2` | 8 | 2 | Bullet gap, chip padding |
| `spacing3` | 12 | 3 | Between blocks |
| `spacing4` | 16 | 4 | Sidebar padding, card inset |
| `spacing5` | 20 | 5 | Section gap in editor |
| `spacing6` | 24 | 6 | Editor outer padding |
| `spacing7` | 28 | 7 | Rare; large section break |
| `spacing8` | 32 | 8 | Sheet margins |
| `spacing10` | 40 | 10 | Empty state vertical |
| `spacing12` | 48 | 12 | Hero empty state |

### Swift mapping

```swift
VStack(spacing: DesignTokens.Spacing.spacing3) { ... }
    .padding(DesignTokens.Spacing.spacing6)
```

### Insets (composite)

| Token | Composition | Use |
|-------|-------------|-----|
| `editorPadding` | all `spacing6` | Editor scroll content |
| `sidebarPadding` | horizontal `spacing4`, vertical `spacing2` | Sidebar list |
| `inspectorPadding` | all `spacing4` | Inspector stack |
| `captureSheetPadding` | all `spacing6` | Quick capture |

---

## Radius

| Token | Points | Use |
|-------|--------|-----|
| `none` | 0 | Full-bleed previews |
| `small` | 6 | Code block, tags |
| `medium` | 8 | Cards, graph nodes |
| `large` | 12 | Sheets, panels |
| `xlarge` | 16 | Modal dialogs (rare) |
| `full` | 9999 | Pills, avatars |

```swift
RoundedRectangle(cornerRadius: DesignTokens.Radius.medium)
```

---

## Shadow

Shadows are used sparingly on macOS.

| Token | Radius | Y offset | Opacity | Use |
|-------|--------|----------|---------|-----|
| `none` | 0 | 0 | 0 | Default flat UI |
| `subtle` | 4 | 1 | 0.08 (light) | Hover lift on cards |
| `floating` | 16 | 4 | 0.12 (light) | Capture sheet, inspector popover |
| `elevated` | 24 | 8 | 0.16 (light) | Rare modals |

Dark mode: reduce opacity by ~40% for equivalent perceived depth.

Swift: `DesignTokens.Shadow.floating` returns `(color, radius, x, y)`.

---

## Motion (cross-reference)

Duration and easing tokens live in `DesignTokens.Motion` and are documented in [Motion.md](./Motion.md).

| Token | Seconds |
|-------|---------|
| `durationInstant` | 0.08 |
| `durationFast` | 0.15 |
| `durationStandard` | 0.22 |
| `durationSlow` | 0.32 |
| `durationEmphasis` | 0.45 |

---

## Layout constants

| Token | Value | Notes |
|-------|-------|-------|
| `sidebarMinWidth` | 220 | Matches current `ContentView` |
| `sidebarMaxWidth` | 280 | User resize clamp |
| `inspectorMinWidth` | 280 | AI + backlinks |
| `inspectorMaxWidth` | 360 | |
| `mainMinWidth` | 480 | Below this, collapse inspector first |
| `editorMaxContentWidth` | 720 | Centered column |
| `captureSheetWidth` | 520 | Quick capture |
| `captureSheetMinHeight` | 200 | |
| `graphNodeMinSize` | 44 | Touch/click target |
| `toolbarHeight` | 52 | Standard unified toolbar |

---

## SwiftUI usage examples

### Themed background

```swift
NavigationSplitView {
    sidebar
        .background(DesignTokens.Color.background)
} detail: {
    detail
        .background(DesignTokens.Color.background)
}
```

### Block quote (editor)

```swift
Text(block.text)
    .font(DesignTokens.Typography.body)
    .padding(.leading, DesignTokens.Spacing.spacing3)
    .overlay(alignment: .leading) {
        Rectangle()
            .fill(DesignTokens.Color.separator)
            .frame(width: 3)
    }
```

### Danger button

```swift
Button("Delete vault", role: .destructive) { }
    .foregroundStyle(DesignTokens.Color.danger)
```

---

## Asset catalog

| Asset | Maps to |
|-------|---------|
| `AccentColor` | `DesignTokens.Color.accent` (keep in sync) |
| `AppIcon` | Marketing only |

Future: optional `Colors.xcassets` for semantic sets if we move off programmatic colors; token **names** remain stable.

---

## Changelog

| Version | Change |
|---------|--------|
| 1.0 | Initial token set aligned with scaffold UI |

---

*See also: [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) · [Components.md](./Components.md)*
