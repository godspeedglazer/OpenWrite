# OpenWrite Design Language

**Version:** 2.1  
**Status:** Canonical  
**Audience:** Design, engineering, and agent implementers

---

## Table of contents

1. [Introduction](#introduction)
2. [Principles](#principles)
3. [Visual identity](#visual-identity)
4. [Custom shell (not default HIG chrome)](#custom-shell-not-default-hig-chrome)
5. [Layout grammar](#layout-grammar)
6. [Typography & voice](#typography--voice)
7. [Iconography](#iconography)
8. [States & feedback](#states--feedback)
9. [Dark mode & appearance](#dark-mode--appearance)
10. [Resize & column behavior](#resize--column-behavior)
11. [Anti-patterns](#anti-patterns)
12. [Governance](#governance)

---

## Introduction

OpenWrite is a native macOS application for private knowledge work: encrypted vaults, structured notes in **NDL** (Note Design Language), backlinks and graph navigation, and **local** retrieval-augmented generation through LM Studio. The interface must communicate trust (your data stays on disk), competence (native speed), and respect for deep work (calm, predictable chrome).

This document defines the **why** and **what** of the design language. Concrete numbers live in [Tokens.md](./Tokens.md); OW primitives in [OWComponents.md](./OWComponents.md); workbench patterns in [Components.md](./Components.md).

### Design goals

| Goal | Measure |
|------|---------|
| **Trust** | Vault lock/unlock states are clear; encryption never feels like a dark pattern |
| **Flow** | Capture → edit → link → retrieve without modal dead-ends |
| **Clarity** | Hierarchy readable at a glance; AI citations traceable to blocks |
| **Distinct shell** | Custom rounded surfaces, **OWIcon** + bundled type — not SF Symbols or default HIG chrome (Anytype-*inspired* density, clean-room) |
| **Accessibility** | Full keyboard paths; VoiceOver labels on all actionable chrome |

### Non-goals (v1)

- Custom illustration system or mascot branding
- Gamification (streaks, achievements)
- Dense “dashboard” analytics on launch
- Skeuomorphic leather, neon cyberpunk, or glassmorphism stacks
- Pixel-parity or asset copy from Anytype, Logseq, or AFFiNE (behavior and density only)

---

## Principles

### 1. Local

**Definition:** The source of truth is the vault on disk. Network is optional (LM Studio on localhost). Sync, if it ever ships, is explicit and secondary.

**UI implications:**

- Prefer **determinate** progress (indexing 240/1200 chunks) over infinite spinners when work is measurable.
- Label AI connectivity honestly: “LM Studio unreachable” not “Something went wrong.”
- Empty states explain *local* next steps (“Create a note”, “Import Markdown”) rather than sign-in CTAs.
- Avoid cloud iconography, gradient “sync” animations, or account avatars in the default shell.

**Copy tone:** Factual, short. “Vault locked” not “Your workspace is waiting in the cloud.”

### 2. Calm

**Definition:** The interface recedes so thought stays in the document. Visual excitement is reserved for rare events (destructive confirm, breach-style alerts—not applicable to OpenWrite’s threat model in v1).

**UI implications:**

- **One accent hue** (OpenWrite teal-blue) for links, selection, and primary actions; neutrals carry structure.
- **Whitespace** over borders: use `surface` elevation and spacing before adding hairlines everywhere.
- **Motion** is subtle and short; see [Motion.md](./Motion.md).
- Sidebars use **custom rows** (`OWSidebarRow`) on a soft gray rail—not default `List` sidebar chrome. Inspectors use **OW Rect** cards, not vibrancy stacks.

**Calm ≠ boring:** Use typography scale and block structure in the editor to create rhythm; chrome stays flat.

### 3. Author-first

**Definition:** The human is the primary “generator”; AI retrieves, suggests, and cites from *your* notes (Reor dual-generator model). The product never impersonates the author’s voice by default.

**UI implications:**

- **Editor column** receives the widest min-width and brightest `textPrimary`.
- AI panel shows **citations** (note title, block ID) beside suggestions; chat input is secondary to the open note.
- Autocomplete and ghost text, when added, are **opt-in** and visually distinct (muted, dashed underline)—never identical to user-typed body text.
- Graph and search are **navigation tools**, not the default landing unless the user chooses that section.

**Ethical UI:** No dark patterns that auto-send vault content to remote endpoints; settings for AI are visible in the inspector, not buried three levels deep.

---

## Visual identity

### Brand personality

| Attribute | Expression |
|-----------|------------|
| **Thoughtful** | Measured spacing, complete sentences in empty states |
| **Precise** | 4pt grid, aligned baselines, monospaced code blocks |
| **Warm-neutral** | Paper-like backgrounds, not sterile hospital white or OLED black |
| **Confident** | Product accent for links/actions; **object-type** accents are muted chips only |

### Color philosophy

OpenWrite uses **semantic tokens**, not raw hex in views. Semantic names describe *role* (`background`, `surface`, `accent`) so light/dark and future high-contrast themes swap without refactors.

- **Background:** Window and split-view canvas
- **Surface:** Sidebar rows, inspector panels, code block fills
- **Accent:** Links, wikilinks, primary buttons, graph focus ring
- **Danger:** Destructive actions, failed unlock, crypto errors

Accent aligns with `AccentColor` in the asset catalog: a clear, readable blue-teal (~sRGB 58, 107, 224) that passes contrast on both appearances.

See [Tokens.md § Color](./Tokens.md#color).

### Shape language — OW Rect

OpenWrite does **not** rely on system sidebar/list chrome. Surfaces use **OW Rect**: rounded rectangles at **10–12pt** (`Radius.owRect`, default 11pt).

- **OW Rect** (11pt): sidebar cards, property strips, capture panel, inspector sections
- **Small** (6pt): code blocks, inline controls
- **Pill** (`Radius.pill`): sidebar **selection** states and `OWObjectTypeChip`—white elevated pill on gray sidebar
- **Sheets** (12–16pt): modal create-page, import flows

Primary actions in toolbars may use `.borderedProminent`; **navigation** is always custom OW components.

### Elevation

macOS prefers **flat** UIs. OpenWrite uses:

1. **Spacing** (primary separator)
2. **Subtle shadow** on floating sheets only (`shadowFloating`)
3. **1px separators** (`separator`) between sidebar and content when needed

Avoid stacked drop shadows and Material-style blur panels except where AppKit requires vibrancy in the title bar (system-controlled).

---

## Custom shell (not default HIG chrome)

### Principle

OpenWrite is a **macOS app** but **not** an Apple HIG / SF Symbols product UI. We borrow platform affordances (menus, shortcuts, `Settings`, standard alerts, split-view geometry) while **drawing our own** navigation rail, icons, typography, selection pills, and editor canvas—similar *density and calm* to Anytype, without copying its assets.

**Hard rules:** No SF Symbols in product surfaces; bundled fonts via `DesignTokens.Typography`; AI inspector sub-flows expose **back** navigation. Details: [ProductDirection.md](./ProductDirection.md) · [AntiPatterns.md](./AntiPatterns.md).

| Zone | Appearance |
|------|------------|
| **Sidebar** | Light gray `#F5F5F7`-ish (`sidebarBackground`); rows 36–40pt; **pill selection** (white on gray) |
| **Editor** | White (`editorCanvas`); max-width column; `OWPageHero` for titles / empty states |
| **Inspector** | Slightly elevated OW Rect panels on `background` |
| **Borders** | 1px `borderSubtle` between columns and on cards—never heavy separator lines |

Implementation: [OWComponents.md](./OWComponents.md).

### What we keep from the platform

| Platform | OpenWrite approach |
|----------|-------------------|
| **Split layout** | `NavigationSplitView` for column geometry only—**not** `.listStyle(.sidebar)` for vault list |
| **Toolbars** | `ToolbarItem` for document actions; styling via tokens |
| **Settings** | `Settings` scene (`Cmd+,`) |
| **Sheets / alerts** | System presentation; **content** uses OW Rect + tokens |
| **Keyboard** | Full command shortcuts; see [Accessibility.md](./Accessibility.md) |
| **Split resize** | Native column dividers with token clamps; collapse order in [ProductDirection.md § Resize](./ProductDirection.md#resize-rules) |

### What we deliberately avoid

- **SF Symbols** and `Image(systemName:)` anywhere in vault, editor, inspector, graph, or AI UI
- Default sidebar `List` selection highlight and disclosure chrome for the vault
- `.bordered` / `.borderedProminent` system buttons as the *primary* brand actions
- System secondary backgrounds in the editor column (always `editorCanvas`)
- Glass / vibrancy stacks in the workbench body
- Grouped `Form` layouts in the editor or inspector content areas

---

## Layout grammar

### Workbench zones

```
┌──────────────┬────────────────────────────────────┬─────────────┐
│   Sidebar    │           Main content             │  Inspector  │
│   (nav)      │   (editor / graph / search / AI)   │  (context)  │
│   260–300pt  │           flex (min 480pt)         │  280–360pt  │
└──────────────┴────────────────────────────────────┴─────────────┘
```

| Zone | Min width | Max width | Collapsible |
|------|-----------|-----------|-------------|
| Sidebar | 260 | 300 | Yes (`Cmd+Ctrl+S`) |
| Main | 480 | — | No |
| Inspector | 280 | 360 | Yes (`Cmd+Option+I`) — **collapsed by default**; product cap 320pt at launch |

**Resize:** Clamps match [Tokens.md § Layout](./Tokens.md#layout-constants). Below **900pt** window width, collapse inspector before sidebar; never shrink main below 480pt. Full rules: [ProductDirection.md § Resize](./ProductDirection.md#resize-rules).

### Spacing rules

- Outer window padding: `spacing6` (24pt) in editor; `spacing4` (16pt) in sidebars
- Section gaps: `spacing5` (20pt) between editor title and first block
- Block gap: `spacing3` (12pt) between NDL blocks
- Inline control gap: `spacing2` (8pt)

All spacing derives from the **4pt grid** — [Tokens.md § Spacing](./Tokens.md#spacing).

### Content width

- Editor text column: **max 720pt** centered in the main column for comfortable line length (~65–75 characters at body size)
- Graph view: uses full main column
- AI chat: inspector width; messages wrap, code blocks scroll horizontally

---

## Typography & voice

### Bundled typography (required)

OpenWrite does **not** use San Francisco as the product UI face. Register **bundled** UI and mono fonts in the app target (`Resources/Fonts/`) and expose them only through **`DesignTokens.Typography`** (SwiftUI `Font` helpers such as `Font.owBody`, `Font.owDocumentTitle`).

| Role | Token | Use |
|------|-------|-----|
| Document title | `documentTitle` | Note H0 in editor |
| Section | `heading1` … `heading3` | NDL headings |
| Body | `body` | Paragraphs, list items |
| Secondary | `callout` + `textSecondary` | Timestamps, metadata |
| Caption | `caption` | AI status, indexer progress |
| Code | `code` / `codeSmall` | NDL code blocks, citation IDs |
| Sidebar | `sidebarItem`, `sidebarSection` | Nav rail |

**Exceptions:** Native alert/sheet chrome AppKit draws; optional system font inside user content when NDL does not specify a family.

Details: [Tokens.md § Typography](./Tokens.md#typography).

### UI copy voice

- **Sentence case** for headings and buttons (“Check connection”, not “Check Connection”)
- **No exclamation marks** in empty states
- **Error messages** include what failed and one recovery action
- **AI strings** attribute sources: “From *Meeting notes* · block `a1b2`”

---

## Iconography

### OWIcon (required; SF Symbols forbidden)

All navigation, toolbar, metadata, and empty-state icons use **`OWIcon`** — template assets in `Assets.xcassets/OWIcons/` (or `Resources/Icons/`), rendered at fixed frames with semantic tints. **Do not** use `Image(systemName:)`, `Label(..., systemImage:)`, or SF-based `ContentUnavailableView` in product UI.

| Context | Size frame | Tint |
|---------|------------|------|
| Sidebar row | 18pt (`sidebarRowIconSize`) | `textSecondary` or `ObjectType.accent(for:)` |
| Toolbar | 20pt | `textPrimary` / `accent` when emphasized |
| Page hero | 48pt | `accent` or object-type accent |
| Inspector row | 16pt | `textSecondary` |
| AI back control | 20pt | `textPrimary` |

Catalog names are stable API (`OWIcon.notes`, `OWIcon.graph`, `OWIcon.ai`, …). Spec: [OWComponents.md § OWIcon](./OWComponents.md#owicon).

### App icon

App icon lives in `Assets.xcassets/AppIcon`. Design direction (product, not spec art): simple mark suggesting an open page and link node—**not** copied from any competitor glyph set.

---

## States & feedback

### Loading

| Context | Pattern |
|---------|---------|
| Vault unlock | ProgressView + “Unlocking vault…” |
| Indexing | Thin progress bar under toolbar; caption with counts |
| LM Studio check | Inline caption in AI section; no blocking modal |
| Graph layout | Skeleton nodes or spinner centered in graph column |

### Success

- Brief **caption** confirmation (“Saved”, “Copied link”) — no toast overlay in v1 unless user enables it in settings later
- Prefer **inline** state change (checkmark on button) for discrete actions

### Errors

- Use `danger` color for text and outline on the affected control
- `alert` for irreversible actions only
- Crypto errors: plain language, link to documentation anchor in help

### Selection

- Sidebar: **pill** on `selectionPill` via `OWSidebarRow`; see [OWComponents.md § OWSidebarRow](./OWComponents.md#owsidebarrow)
- Editor: accent-tinted caret; block focus ring `accent` at 40% opacity, 2pt width
- Graph: node stroke `accent`, width 2pt

---

## Dark mode & appearance

Both appearances share the same semantic structure; only luminance and separator contrast change.

| Token | Light intent | Dark intent |
|-------|--------------|-------------|
| `background` | Warm off-white window | Near-black window, not pure #000 |
| `surface` | Slightly darker than background | Elevated gray panel |
| `textPrimary` | Near-black | Near-white |
| `textSecondary` | 55% primary | 65% primary |
| `separator` | 12% black | 18% white |

Users who need higher contrast may use system **Increase Contrast**; tokens should be revisited if audit fails WCAG AA — see [Accessibility.md](./Accessibility.md).

---

## Resize & column behavior

OpenWrite uses `NavigationSplitView` for column geometry only; visual chrome is custom. **Resize rules** (clamps, collapse priority, 900pt breakpoint) are canonical in [ProductDirection.md § Resize rules](./ProductDirection.md#resize-rules).

Summary:

- Sidebar **260–300pt**; inspector **280–360pt** (default open ≤ **320pt**); main **≥ 480pt**.
- **Inspector collapses first** when the window narrows; sidebar second.
- Editor text column stays **max 720pt** centered inside main — not a fourth split divider.

---

## Anti-patterns

Do **not** ship SF Symbols, default HIG `Form`/`List` chrome, or system accent blue as the product face. Full list: **[AntiPatterns.md](./AntiPatterns.md)**.

Highlights:

1. **SF Symbols** in any product surface — use `OWIcon`.
2. **San Francisco as default UI font** — use bundled fonts via tokens.
3. **AI sub-panels without back** — use `OWAIPanelHeader` when depth ≥ 1.
4. **Splash indexing gates** — block editing while “syncing” the entire vault (Reor anti-pattern).
5. **Full-screen AI** on launch — author-first requires editor or last document.
6. **Default `List` sidebar** — use `OWSidebarRow`.
7. **Inspector half the window** — collapse by default; see resize rules.
8. **Copy Anytype** assets or exact hex — inspiration only.
9. **Arbitrary per-keystroke animation** — [Motion.md](./Motion.md).

---

## Governance

### Adding a new surface

1. Sketch zone placement (sidebar / main / inspector).
2. List required tokens; add to `Tokens.md` and `DesignTokens.swift` in one PR.
3. Document in `OWComponents.md` (primitives) or `Components.md` (screens); wire tokens in `DesignTokens.swift`.
4. Verify reduced motion and keyboard path.

### Review checklist

- [ ] Uses semantic tokens only
- [ ] **No SF Symbols** in `OpenWrite/UI/**` (see [AntiPatterns.md](./AntiPatterns.md))
- [ ] Typography uses **bundled** fonts through `DesignTokens.Typography`
- [ ] Editor remains visually dominant for writing flows
- [ ] AI inspector sub-flows have **back** when stacked depth ≥ 1
- [ ] Column widths respect resize clamps and collapse order
- [ ] No network-required empty state
- [ ] VoiceOver labels on icon-only controls (`OWIcon` + text label)
- [ ] Animations use `Motion` durations and respect `accessibilityReduceMotion`

### References (external)

- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui) — APIs only; OpenWrite is **not** an HIG-default UI
- OpenWrite master plan: [../OpenWriteMasterPlan.md](../OpenWriteMasterPlan.md)
- Design direction: [ProductDirection.md](./ProductDirection.md) · [AntiPatterns.md](./AntiPatterns.md)

---

*End of OpenWrite Design Language v2.1*
