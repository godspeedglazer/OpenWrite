# Reference UI layouts

**Version:** 1.0  
**Last updated:** 2026-05-17  
**Audience:** Design and UI implementers  
**Product scope:** [../ProductDirection.md](../ProductDirection.md) · [ProductDirection.md](./ProductDirection.md) (design non-negotiables)  
**Related:** [LayoutAndResize.md](./LayoutAndResize.md) · [AnytypeUIInspiration.md](./AnytypeUIInspiration.md) · [EditorAndAIPanel.md](./EditorAndAIPanel.md) · [features/DatabasePresets.md](../features/DatabasePresets.md)

This page turns **user-provided reference captures** (May 2026) into **layout rules** for OpenWrite. Patterns are observed from competitors for information architecture only — see [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) clean-room policy.

---

## Reference captures

Paths below live in the Cursor workspace assets folder during design sessions. Copy into `docs/assets/reference-layouts/` when versioning in git.

| ID | App | File | What it shows |
|----|-----|------|----------------|
| **OW-current** | OpenWrite | [image-4e8a71d7](../../../.cursor/projects/Users-erichspringer-Downloads-OpenWrite/assets/image-4e8a71d7-9e9f-468c-8be4-f86758ffed6a.png) | Three-region shell; welcome page with **Page type** card row; large white void below; AI assist footer strip |
| **Anytype-types** | Anytype | [image-f54fb832](../../../.cursor/projects/Users-erichspringer-Downloads-OpenWrite/assets/image-f54fb832-ddbc-4acd-a94e-a0d0f6823999.png) | Object Types sidebar: dense icon+label list, search + **New**, empty main with **+ New Object** CTA |
| **Reor** | Reor | [image-63ff2884](../../../.cursor/projects/Users-erichspringer-Downloads-OpenWrite/assets/image-63ff2884-fb90-4aef-9de6-db11aaa6427c.png) | Editor **center hero**; chat column **narrow** on the right with sources + composer |
| **massCode** | massCode | [image-368f43d0](../../../.cursor/projects/Users-erichspringer-Downloads-OpenWrite/assets/image-368f43d0-7973-47fa-a64d-7916198d40e6.png) | Four columns: icon rail → library/folders → item list → editor |

---

## OpenWrite target shell (synthesis)

Default window **1200×800**. Writing mode is **three content regions**; database lens may add a **fourth list/table column** (massCode pattern).

```
Writing mode (default)
┌─ Sidebar ─────┬────────── Editor (flex, ≥55% content) ──────────┬─ Inspector (0 or ≤35%) ─┐
│ Vault + types │  OWPageHero + block editor (hero)                 │ Chat | Related | Past    │
└───────────────┴──────────────────────────────────────────────────┴──────────────────────────┘

Database lens (optional 4th column)
┌─ Sidebar ─┬─ DB nav ─┬─ Row list / table ─┬─ Editor ─┬─ Inspector (collapsed) ─┐
│           │ folders  │  OWDatabase view    │  detail  │                            │
└───────────┴──────────┴─────────────────────┴──────────┴────────────────────────────┘
```

Aligns with [ProductDirection.md § Writing-first](../ProductDirection.md#2-writing-first-ai-second-reor-dual-generator) and [design/ProductDirection.md § Writing-first layout](./ProductDirection.md#writing-first-layout-unchanged).

---

## Rule 1 — Empty states: CTA row, not blank canvas

**Reference:** Anytype **+ New Object** (types capture); **anti-reference:** OpenWrite current capture (card row then huge void).

| Do | Don’t |
|----|--------|
| Show a **single purposeful CTA row** at the top of the main column when there is no body content | Centered “nothing here” on an unbounded white field |
| Use **one primary action** (+ New page, + New row, + New object in this database) plus optional secondary links | Five full-width type cards that consume vertical space and leave the editor as dead air |
| Pre-fill **welcome** or template body so `TextEditor` has scrollable content on first launch | Empty `TextEditor` with only chrome above it |
| In **database** empty views, mirror Anytype: **+ New row** (or + New snippet) under the view toolbar | “No Notes” floating in the middle of a column with no affordance above the fold |

### CTA row anatomy

| Element | Placement | Notes |
|---------|-----------|-------|
| Primary CTA | Leading, `Typography.sidebarItem` weight 500 | `OWIcon` + label; not SF Symbols |
| Secondary | Trailing same row | Filter, sort, view switcher — compact icon buttons |
| Tertiary empty hint | Below CTA row only if needed | One line `textSecondary`; no second hero |

### Page-type selection

- **New page:** type/template picker in **sheet** or compact **horizontal chip strip** after first save — not a permanent block in the editor column ([ProductDirection.md § Next 30 days #7](../ProductDirection.md#6-next-30-days--ui-priorities)).
- **Open page:** hero (`OWPageHero`) + collapsed **Properties** disclosure by default; editor grows with `maxHeight: .infinity`.

### Empty-state matrix

| Surface | Empty CTA | Component |
|---------|-----------|-----------|
| Vault (no selection) | “Select a page” or auto-open welcome | `OWPageHero` + body seed |
| Editor (no blocks) | Inline “Start writing…” or seeded welcome NDL | Editor, not void |
| Database view (no rows) | **+ New row** under toolbar | `OWDatabase` lens |
| Graph | “Link pages with `[[wikilinks]]`” + open note CTA | Graph stub |
| Inspector chat | Compact prompt chips | [Components.md](./Components.md) § AI panel |

---

## Rule 2 — Reor posture: chat never >35% width

**Reference:** Reor capture — center document ~50–60% of window; chat ~25–30%.

OpenWrite inspector holds vault chat ([EditorAndAIPanel.md](./EditorAndAIPanel.md)). The Reor mistake OpenWrite must not repeat is an always-open chat column that **competes with the manuscript** ([ProductDirection.md reference captures](../ProductDirection.md#reference-captures-user-provided-2026-05-17)).

### Width rules

| Measure | Rule | Token / note |
|---------|------|----------------|
| **Inspector share** | ≤ **35%** of **content width** (window minus sidebar) | `inspectorMaxWidthFraction = 0.35` |
| **Hard cap** | ≤ **360pt** absolute | `DesignTokens.Layout.inspectorMaxWidth` |
| **Effective max** | `min(0.35 × contentWidth, 360pt)` | At 1200pt window ≈ **325pt** |
| **Default** | **Collapsed** or **320pt** when opened | [design/ProductDirection.md](./ProductDirection.md#width-clamps) |
| **Editor share** | ≥ **55%** of content width at default size | Complement of sidebar + inspector |
| **Editor minimum** | ≥ **480pt** | `mainMinWidth`; collapse inspector before violating |

### Collapse priority (narrow window)

When `contentWidth < sidebarMin + mainMin + inspectorMin`:

1. Collapse **inspector** (AI off).
2. Collapse **database list column** (if open).
3. Collapse **sidebar** last.
4. Never shrink editor below `mainMinWidth`.

### Reor vs OpenWrite mapping

| Reor column | OpenWrite |
|-------------|-----------|
| Icon rail | Sidebar sections (Objects, Vault, Pinned) |
| Recents + Start chat | Inspector **Chat** tab (not sidebar) |
| Center editor | **Editor** detail column |
| Right chat | **Inspector** — same role, stricter width cap |

**Anti-pattern (current OW capture):** AI assist as a **bottom strip** plus wide inspector — reads as chat owning the workbench. Inspector is trailing only; LM Studio belongs in Settings, not the rail ([ProductDirection.md § Layout rules](../ProductDirection.md#layout-rules-non-negotiable-for-v1-ui)).

---

## Rule 3 — Anytype object-type list density

**Reference:** Anytype Object Types sidebar — tight rows, section labels, search + **New** on one line.

### Sidebar list metrics (target)

| Property | Target | OpenWrite |
|----------|--------|-----------|
| Row height | **28–32px** visual (36–38pt hit target) | `Layout.sidebarRowHeight` (tune toward **36pt** if rows feel loose) |
| Horizontal padding | **8pt** inset | `Spacing.spacing2` |
| Icon well | **20–24pt** | `OWIcon` template, object-type tint |
| Section header | Small caps / `textSmall`, secondary | `OWSidebarSection` (future) |
| Selection | Inset pill on gray rail | `OWSidebarRow` |
| Search + action | One row: field + **New** | Vault toolbar pattern |

### Type list content

- Group **My types** vs **Built-in types** (mirrors Anytype My / System) — preset `PageType` + user `OWDatabase` templates.
- **Do not** use `List` with full-width system selection; use custom rows per [AnytypeUIInspiration.md § Sidebar pills](./AnytypeUIInspiration.md#1-sidebar-pills-and-row-chrome).
- Object-type picker for **new page** is **not** the permanent center column — it lives in sidebar density or a sheet.

### Main column when a type/database is selected

- Toolbar: view name, filter/sort icons, **New** dropdown (trailing).
- Empty body: **+ New Object** / **+ New row** as first line — not vertical centering in 600pt of white.

---

## Rule 4 — massCode: optional fourth column for database table view

**Reference:** massCode Notes — icon rail | library/folders | note list | editor.

OpenWrite generalizes massCode into **`OWDatabase`** ([DatabasePresets.md](../features/DatabasePresets.md)) — not a separate snippet app.

### Column mapping

| massCode | OpenWrite (writing) | OpenWrite (database lens) |
|----------|---------------------|---------------------------|
| Icon rail (~48pt) | Sidebar **section** icons (optional compact mode) | Same |
| Library + folders | Vault tree + database sidebar | **DB nav** column |
| Note list | Vault page list in sidebar | **Row list** column (~240–280pt) |
| Editor | Editor + `OWPageHero` | Editor (row detail) |
| — | Inspector (collapsed default) | Inspector collapsed |
| *(n/a)* | — | **Table view** column when `view.layout == table` |

### When to show the fourth column

| Condition | Columns (left → right) |
|-----------|-------------------------|
| Normal note editing | Sidebar \| Editor \| Inspector? |
| Database selected, **list** layout | Sidebar \| DB nav \| Row list \| Editor |
| Database selected, **table** layout | Sidebar \| DB nav \| **Table** \| Editor (list hidden or split) |
| Window &lt; **1100pt** | Collapse table → list-only; or list → sidebar subsection |
| User preference “Compact database” | Merge list into sidebar (3 columns max) |

### Table column rules

| Property | Value |
|----------|-------|
| Min width | **280pt** |
| Max width | **480pt** (user drag) |
| Default | **360pt** |
| Content | Sortable columns from `OWDatabase` view schema; row click selects document in editor |
| Growth | `layoutPriority(0)` — yields to editor before editor hits `mainMinWidth` |

Snippet Store preset is the first consumer ([DatabasePresets.md § snippet_store](../features/DatabasePresets.md#built-in-presets)).

---

## Proportion cheat sheet (1200pt window)

Assume sidebar **272pt**, split chrome **~16pt**, content **≈912pt**:

| Region | % of content | pt (approx) | Rule source |
|--------|--------------|-------------|---------------|
| Editor | **≥ 55%** | **≥ 502** | ProductDirection |
| Inspector (open) | **≤ 35%** | **≤ 319** | Reor reference + cap 360 |
| DB list column | **~26%** | **~240** | massCode middle pane |
| DB table column | **~30–40%** | **280–360** | Optional 4th |

---

## Implementation checklist

| Priority | Change | Captures addressed |
|----------|--------|-------------------|
| P0 | Inspector default **collapsed**; enforce `min(0.35 × content, 360)` | Reor, OW-current |
| P0 | Remove permanent **Page type** card grid from editor; sheet + compact chips | OW-current, Anytype |
| P0 | Editor `frame(maxHeight: .infinity)`; welcome body pre-filled | OW-current |
| P1 | Sidebar type list at **36pt** rows; search + New row | Anytype |
| P1 | Database empty: **+ New row** CTA under toolbar | Anytype, massCode |
| P2 | Optional **table column** for `OWDatabase` table layout | massCode |
| P2 | Persist column widths in `WorkbenchState` | LayoutAndResize |

---

## Layout token stub (for `DesignTokens.Layout`)

Add when wiring clamps in Swift — names only; values live in [Tokens.md](./Tokens.md):

```swift
// ReferenceUILayouts.md — not yet in DesignTokens.swift until E-08
static let inspectorMaxWidthFraction: CGFloat = 0.35
static let editorMinContentWidthFraction: CGFloat = 0.55
static let databaseListColumnMinWidth: CGFloat = 240
static let databaseListColumnMaxWidth: CGFloat = 280
static let databaseTableColumnMinWidth: CGFloat = 280
static let databaseTableColumnMaxWidth: CGFloat = 480
static let databaseTableColumnDefaultWidth: CGFloat = 360
```

---

## Cross-links

| Topic | Document |
|-------|----------|
| Product thesis, 30-day UI | [../ProductDirection.md](../ProductDirection.md) |
| SF ban, resize clamps, AI back | [ProductDirection.md](./ProductDirection.md) |
| Split implementation | [LayoutAndResize.md](./LayoutAndResize.md) |
| Anytype density detail | [AnytypeUIInspiration.md](./AnytypeUIInspiration.md) |
| Chat placement | [EditorAndAIPanel.md](./EditorAndAIPanel.md) |
| OW primitives | [OWComponents.md](./OWComponents.md) |
| Database schemas | [../features/DatabasePresets.md](../features/DatabasePresets.md) |

*Update when new reference captures arrive or column clamps ship in `DesignTokens.swift`.*
