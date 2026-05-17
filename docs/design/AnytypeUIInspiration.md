# Anytype Desktop UI — Inspiration Notes (Clean-Room)

**Version:** 1.0  
**Date:** 2026-05-17  
**Source tree (read-only reference):** `anytype-ts-develop/` (Anytype TypeScript/Electron client)  
**OpenWrite status:** Inspiration only — **ASAL** (as similar as lawfully allowed). No verbatim code, assets, icons, or copy.

---

## Legal and implementation boundary

| Allowed | Not allowed |
|---------|-------------|
| Observing layout density, hierarchy, interaction patterns | Copying TS/SCSS/React source into OpenWrite |
| Mapping patterns to **new** SwiftUI in `OpenWrite/UI/Design/` | Importing Anytype SVGs, fonts, or trademarked branding |
| Aligning **behavior** (pill selection, graph entry, page hero stack) with OpenWrite tokens | Pixel-parity or “Anytype clone” positioning |
| Referencing file paths for future human study | Committing or redistributing Anytype source as part of OpenWrite |

OpenWrite already states clean-room intent in [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) and implements primitives in [OWComponents.md](./OWComponents.md). This document bridges **what we observed** in Anytype’s desktop shell to **what we build** with `OWSidebarRow`, `OWRoundedRect`, etc.

---

## Screenshot-aligned patterns (user reference themes)

These sections describe UI regions that commonly appear in Anytype desktop references (sidebar, graph, object page). Names match DOM/CSS classes in the reference app for traceability only.

### 1. Sidebar “pills” and row chrome

**Where it lives:** Left rail → **Widgets** page (`pageWidget`) and **Vault** (`pageVault`); optional **Links** sidebar mode (`SidebarView.Links`).

**Visual pattern**

- **Canvas:** Primary background (`--color-bg-primary`) with **8px** outer padding on the left wrapper; sub-panels use **12px** corner radius on the inner edge (rounded “card” attached to the window).
- **Row hover / selection:** Rows do not rely on a full-width `List` selection. Instead, a **pseudo-element overlay** (`::before`) with `--color-shape-highlight-medium` fades in on hover; **active** rows use a slightly inset overlay (1px inset, ~7px effective radius) so the highlight reads as a **soft pill** inside the row bounds.
- **Vault items:** `padding: 6px 8px`, **`border-radius: 8px`**, 32px icon wells, **font-weight: 500** titles — compact but touchable (~44px row feel).
- **Widget object rows:** 28px row height, **6px** rounded hover plate; selected/active uses the same overlay technique (`widget/object.scss`).
- **Links view:** Body gets horizontal **8px** inset; object names **font-weight: 500** — flatter, link-list density vs. widget cards.
- **Section headers:** Small caps styling via `@include text-small`, **secondary** color, chevron rotation on expand; **8px** vertical gap between sections.
- **Bottom bar controls:** **32×32** circles (`border-radius: 16px`) for settings/sync/help — floating “pill buttons” on a bottom gradient fade.

**OpenWrite mapping**

| Anytype pattern | OpenWrite primitive |
|-----------------|---------------------|
| Inset highlight pill on gray rail | `OWSidebarRow` selection (`selectionPill` on `sidebarBackground`) |
| 28–32px dense nav rows | `Layout.sidebarRowHeight` (38pt target; adjust toward 36pt if matching density) |
| Section labels + disclosure | Custom `OWSidebarSection` (future) — not `List` section headers |
| Circular bottom actions | `OWIconButton` with `Radius.pill` on inspector/sidebar footer |

### 2. Graph tab and graph surfaces

**Entry points (three distinct)**

1. **Global graph route** — `main/graph` → `PageMainGraph` + `Header` `component="mainGraph"`. Full viewport canvas; header center holds **tabs**; right side search + settings icons.
2. **Header graph icon** (object pages) — `Header` `onGraph` → `U.Object.openAuto({ layout: ObjectLayout.Graph })`. Same graph layout with object-centric navigation retained in header left cluster.
3. **Collection/set inline view** — `block/dataview` view type `ViewType.Graph` → `ViewGraph` + `GraphProvider`; inline height **500px**, embedded in editor body.

**Visual pattern**

- Canvas fills available area; background `--color-bg-primary`.
- **Timeline** (global graph): Floating bar **bottom center**, `border-radius: 8px`, shadow, max-width ~600px — playback scrubber, not a permanent sidebar.
- Dataview graph uses horizontal **46px** padding math to bleed graph to page width.

**OpenWrite mapping**

| Anytype pattern | OpenWrite primitive |
|-----------------|---------------------|
| Dedicated graph mode in main column | `NavigationSplitView` detail route or tab: `GraphView` (new) |
| Graph affordance in top chrome | Toolbar item → `GraphView` / “Local graph” (no Anytype icon) |
| Graph as alternate view of a folder/tag | Optional phase-2: graph lens on `OWCollectionView` |
| Floating timeline | `OWFloatingPanel` / bottom overlay only if OpenWrite adds time-based graph |

### 3. Page hero (icon, title, metadata)

**Where it lives:** `headSimple` + block stack inside `editorWrapper` (`PageHeadEditor` wires cover, `IconPage`, title/description blocks, `Featured` relations).

**Visual pattern (top → bottom)**

1. Optional **cover** block (large top padding on wrapper, e.g. **348px** with cover only).
2. **Page icon** (`blockIconPage`) — emoji/image; image icons get **3px** ring in page background color.
3. **Title** — `text-header1` / `text-title` scale in `headSimple.titleWrap`; editable, word-break friendly.
4. **Description** — `text-description`, secondary tone.
5. **Metadata row** — `blockFeatured` **inline** list: relation values in **20px-radius** cells, dot separators, hover highlight on individual cells (not one big bar).

**Sticky chrome (separate from hero)**

- `Header` `mainObject`: **52px** sticky bar; center **path** chip (`border-radius: 6px`, 28px tall) with **18px** `IconObject` + plural name; optional lock/system label pill (`border-radius: 4px`, tertiary fill).

**OpenWrite mapping**

| Anytype pattern | OpenWrite primitive |
|-----------------|---------------------|
| Icon + title + subtitle stack | `OWPageHero` (compose: icon button, `Typography.documentTitle`, caption) |
| Inline metadata chips | `OWMetadataChip` row under hero (map to NDL front-matter / relations) |
| Featured relations row | Inspector “Properties” or hero-adjacent `OWMetadataChip` strip |
| Sticky breadcrumb header | `OWWorkbenchHeader` with note title + vault path (`OWIcon` only) |

---

## Shell layout (editor vs panels)

Anytype’s main window is a **horizontal composition** of fixed sidebars + a **rounded main page card**, not a single full-bleed editor.

```
┌──────────┬─────────────┬──────────────────────────────┬─────────────┐
│  Vault   │  Widgets /  │  #page (border-radius 12px)  │  Right      │
│  (sub)   │  sub-panel  │  ┌ Header 52px sticky ─────┐  │  sidebar    │
│  336px   │  resizable  │  │ Editor / graph / set    │  │  relations  │
│  default │             │  │ editorWrapper ~60% width│  │  TOC, etc.  │
│          │             │  └─────────────────────────┘  │             │
└──────────┴─────────────┴──────────────────────────────┴─────────────┘
         ↑ pageFlex padding 8px; animates when sidebars open/close
```

**Behaviors worth emulating (clean-room)**

- **Independent resize** on left pages and right panel (`SidebarPanel` + drag handles).
- **Main column** stays visually “elevated” (rounded rect) while sidebars sit on `bg-primary`.
- **Editor** is centered with configurable width (`size.editor` = **704** CSS px reference; layout width slider in page head).
- **Right panel** pages: `object/relation`, preview — toggled from header icons, not a permanent triple column on small widths.
- **Page transitions:** `AnimatePresence` fade on `bodyWrapper` when switching objects (~120ms).

OpenWrite already places **RAG chat in the inspector** ([EditorAndAIPanel.md](./EditorAndAIPanel.md)) — analogous to Anytype’s right sidebar, not a bottom chat dock.

---

## Sidebar structure and navigation

### Panel model

| Panel | Role | Default width (from `json/size.ts`) |
|-------|------|-------------------------------------|
| Left (`pageWrapper`) | Widget home, settings entry | default **284**, min **72**, max **480** |
| Sub-left (`subPageWrapper`) | Vault list | **336** fixed wrapper |
| Right | Relations, TOC, preview | resizable |

`SidebarLeft` registers pages: `widget`, `widgetManage`, `vault`, `settings`, `settingsSpace`, `settingsTypes`, `settingsRelations`.

### Widget sidebar content

- Sections: Pin, Favorites, Recent, **Types**, Bin (conditional).
- Each section: collapsible header + virtualized/tree/list widget layouts (`WidgetLayout`: Link, Tree, List, Compact, View).
- **Types section** surfaces object types as navigable groups (onboarding highlights `#section-Type`).

### Vault

- Virtualized list; filter row; **minimal mode** collapses to icon-only column with **4px** accent dot for active item.
- Items use pill hover; chat objects show counter badges on icon wells.

### Object types list styling (Type section + settings)

- Tree widget: **28px** rows, **6px** inner radius, chevron **24px** hit target.
- Type settings sidebar (`pageType`): template carousel cards **96px** tall, **50%** width slides, accent border on default template.
- Relation rows in type editor: **20px** icons, drag handle, hover wash.

---

## Rounded rects, spacing, typography

### Radius scale (observed)

| px | Usage |
|----|--------|
| 3 | Resize handle bar |
| 4 | Small chips, arrows |
| 6 | Path breadcrumb, space switcher, widget row hover |
| 8 | Vault items, graph timeline, manage items |
| 12 | Sidebar sub-page outer corners, main `#page` card |
| 16 | Vault shell, bottom FABs |
| 20 | Featured metadata cells |
| 100px / 50% | Identity chip, circular buttons |

### Spacing rhythm

- **8px** — dominant gap (sections, icon gaps, page flex padding).
- **12px** — sidebar head horizontal padding, manage sections.
- **16px** — widget head padding, graph timeline padding.
- **24px** — hero bottom margin, block icon bottom padding.

### Typography (SCSS mixins → tokens)

| Mixin | Typical use |
|-------|-------------|
| `text-small` | Section labels, timestamps, metadata |
| `text-common` | Body, buttons |
| `text-paragraph` | Tabs (700 weight active) |
| `text-title` | Page titles in blocks |
| `text-header1` | `headSimple` primary title |
| `text-description` | Subtitle / description |

All font sizes are CSS variables (`--font-size-*`, `--line-height-*`). OpenWrite maps to `DesignTokens.Typography.*` — do not copy variable names verbatim if they mirror Anytype’s theme file structure; keep semantic names (`documentTitle`, `sidebarItem`, etc.).

### Motion

- `$transitionCommon`: **0.15s** `cubic-bezier(0.22, 1, 0.36, 1)`
- Sidebar width: **0.2s** decelerate
- Align with [Motion.md](./Motion.md) (`animationFast`, `animationStandard`)

---

## File path index (key UI modules)

### Application shell

| Path | Purpose |
|------|---------|
| `src/ts/app.tsx` | Root router, global SCSS imports |
| `src/ts/component/page/index.tsx` | Page route registry (`main/edit`, `main/graph`, …) |
| `src/scss/page/common.scss` | `pageFlex`, `#page` rounded card |
| `src/json/size.ts` | Sidebar/editor/history dimensions |

### Sidebars

| Path | Purpose |
|------|---------|
| `src/ts/component/sidebar/left.tsx` | Left + sub-left panel host, resize |
| `src/ts/component/sidebar/right.tsx` | Right panel |
| `src/ts/component/sidebar/page/widget.tsx` | Widget home sidebar |
| `src/ts/component/sidebar/page/vault.tsx` | Vault list |
| `src/scss/component/sidebar/common.scss` | Sidebar chrome, radii, resize handles |
| `src/scss/component/sidebar/page/widget.scss` | Widget head, sections, links view |
| `src/scss/component/sidebar/page/vault.scss` | Vault rows, minimal mode |
| `src/scss/component/sidebar/page/bottom.scss` | Bottom pill buttons |
| `src/ts/interface/sidebar.ts` | Panel/direction types |

### Header and navigation

| Path | Purpose |
|------|---------|
| `src/ts/component/header/index.tsx` | Header factory, graph shortcut, tabs |
| `src/ts/component/header/main/object.tsx` | Object breadcrumb header |
| `src/ts/component/header/main/graph.tsx` | Graph mode header |
| `src/scss/component/header.scss` | 52px bar, path, tabs, icon buttons |

### Page hero and editor

| Path | Purpose |
|------|---------|
| `src/ts/component/page/main/edit.tsx` | Header + `EditorPage` shell |
| `src/ts/component/editor/page.tsx` | Block editor orchestration |
| `src/ts/component/page/elements/head/editor.tsx` | Cover/icon/header blocks |
| `src/ts/component/page/elements/head/simple.tsx` | Title, description, featured |
| `src/scss/component/headSimple.scss` | Hero layout |
| `src/scss/component/editor.scss` | `editorWrapper`, width modes, TOC |
| `src/scss/block/iconPage.scss` | Page icon |
| `src/scss/block/featured.scss` | Metadata chip row |
| `src/scss/block/text.scss` | Title/description block styles |

### Graph

| Path | Purpose |
|------|---------|
| `src/ts/component/page/main/graph.tsx` | Full-page graph |
| `src/ts/component/block/dataview/view/graph.tsx` | Inline collection graph |
| `src/ts/component/widget/view/graph/index.tsx` | Widget graph view |
| `src/scss/page/main/graph.scss` | Graph page + timeline |
| `src/scss/block/dataview/view/graph.scss` | Inline graph dimensions |

### Widgets and types list

| Path | Purpose |
|------|---------|
| `src/scss/widget/object.scss` | Sidebar object row pills |
| `src/scss/widget/tree.scss` | Type/tree section rows |
| `src/ts/component/widget/object.tsx` | Object widget behavior |
| `src/ts/component/sidebar/page/type.tsx` | Type editor sidebar |
| `src/scss/component/sidebar/page/type.scss` | Type/template/relation styling |

### Design tokens (reference only)

| Path | Purpose |
|------|---------|
| `src/scss/_mixins.scss` | Typography mixins, transitions |
| `src/scss/color.scss` | Theme color variables |
| `src/json/theme.ts` | Theme metadata |

---

## Clean-room SwiftUI mapping (implementation checklist)

Use this when implementing or extending OpenWrite workbench UI. All names refer to **OpenWrite** types in `OpenWrite/UI/Design/`.

### Layout containers

| Concept | SwiftUI approach |
|---------|------------------|
| Rounded main document card | `OWRoundedRect(style: .editorPanel)` filling `NavigationSplitView` detail |
| Gray sidebar rail | `Color.surface` background; content inset `Spacing.spacing2` |
| Inspector / right panel | Trailing split column; `OWRoundedRect(style: .elevated)` sections |

### Components (existing + suggested)

| OW type | Inspired behavior |
|---------|-------------------|
| `OWRoundedRect` | 11pt corner main surfaces (maps Anytype 12px card, legally distinct constant) |
| `OWSidebarRow` | Vault/widget row hover + selection pill |
| `OWObjectTypeChip` | Featured metadata / type filter chips (20px-scale capsule) |
| `OWPageHero` *(suggested)* | Icon + `documentTitle` + `caption` + optional cover |
| `OWMetadataChip` *(suggested)* | Single relation pill; horizontal `FlowLayout` |
| `OWWorkbenchHeader` *(suggested)* | 52pt sticky bar analogue: back, title path, inspector toggles |
| `OWSidebarSection` *(suggested)* | Collapsible Pin/Recent/Types headers |
| `OWGraphView` *(suggested)* | SwiftUI/SpriteKit/force-directed — **new** implementation |

### Token alignment (do not copy hex from Anytype)

| Observed | OpenWrite token |
|----------|-----------------|
| `--color-shape-highlight-medium` hover | `accentMuted` / overlay on `surface` |
| `--color-bg-primary` page card | `surfaceElevated` or `editorCanvas` |
| 52px header | `Layout.workbenchHeaderHeight` (define if missing) |
| 8px gaps | `Spacing.spacing2` |
| 12px card radius | `Radius.large` or `owRect` per [Tokens.md](./Tokens.md) |

---

## Anti-patterns for OpenWrite

1. **Do not** import Anytype’s icon font or SVG sets — use **`OWIcon`** and original OpenWrite assets only (no SF Symbols).
2. **Do not** replicate exact radii/spacing tables as a “port” — tune against OpenWrite tokens and macOS HIG accessibility.
3. **Do not** use Anytype marketing copy, shortcut names, or onboarding strings.
4. **Avoid** triple-fixed sidebars on narrow windows; prefer collapsible inspector (already decided for AI).
5. **Avoid** binding graph UX to the same backend APIs — OpenWrite graph is local vault topology, not their object graph service.

---

## Related OpenWrite docs

- [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) — principles and clean-room policy  
- [OWComponents.md](./OWComponents.md) — `OWSidebarRow`, `OWRoundedRect` APIs  
- [Tokens.md](./Tokens.md) — canonical numbers  
- [EditorAndAIPanel.md](./EditorAndAIPanel.md) — editor vs inspector split  
- [Components.md](./Components.md) — workbench-level patterns  

---

## Revision history

| Version | Date | Notes |
|---------|------|-------|
| 1.0 | 2026-05-17 | Initial clean-room study of `anytype-ts-develop` for sidebar, graph, and page hero patterns |
