# OpenWrite Design Language

**Version:** 1.0  
**Status:** Canonical  
**Audience:** Design, engineering, and agent implementers

---

## Table of contents

1. [Introduction](#introduction)
2. [Principles](#principles)
3. [Visual identity](#visual-identity)
4. [macOS native feel](#macos-native-feel)
5. [Layout grammar](#layout-grammar)
6. [Typography & voice](#typography--voice)
7. [Iconography](#iconography)
8. [States & feedback](#states--feedback)
9. [Dark mode & appearance](#dark-mode--appearance)
10. [Anti-patterns](#anti-patterns)
11. [Governance](#governance)

---

## Introduction

OpenWrite is a native macOS application for private knowledge work: encrypted vaults, structured notes in **NDL** (Note Design Language), backlinks and graph navigation, and **local** retrieval-augmented generation through LM Studio. The interface must communicate trust (your data stays on disk), competence (native speed), and respect for deep work (calm, predictable chrome).

This document defines the **why** and **what** of the design language. Concrete numbers live in [Tokens.md](./Tokens.md); component anatomy in [Components.md](./Components.md).

### Design goals

| Goal | Measure |
|------|---------|
| **Trust** | Vault lock/unlock states are clear; encryption never feels like a dark pattern |
| **Flow** | Capture → edit → link → retrieve without modal dead-ends |
| **Clarity** | Hierarchy readable at a glance; AI citations traceable to blocks |
| **Native fit** | Could be mistaken for an Apple-adjacent productivity app at arm’s length |
| **Accessibility** | Full keyboard paths; VoiceOver labels on all actionable chrome |

### Non-goals (v1)

- Custom illustration system or mascot branding
- Gamification (streaks, achievements)
- Dense “dashboard” analytics on launch
- Skeuomorphic leather, neon cyberpunk, or glassmorphism stacks
- Pixel-parity with Electron competitors (Anytype, Logseq, AFFiNE web)

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
- Sidebars and inspectors default to **visible but quiet**—secondary text, sidebar list style, no heavy cards in the nav.

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
| **Confident** | Single accent; no rainbow category colors in v1 |

### Color philosophy

OpenWrite uses **semantic tokens**, not raw hex in views. Semantic names describe *role* (`background`, `surface`, `accent`) so light/dark and future high-contrast themes swap without refactors.

- **Background:** Window and split-view canvas
- **Surface:** Sidebar rows, inspector panels, code block fills
- **Accent:** Links, wikilinks, primary buttons, graph focus ring
- **Danger:** Destructive actions, failed unlock, crypto errors

Accent aligns with `AccentColor` in the asset catalog: a clear, readable blue-teal (~sRGB 58, 107, 224) that passes contrast on both appearances.

See [Tokens.md § Color](./Tokens.md#color).

### Shape language

- **Small radius** (6pt) for inline chips, code blocks, capture field
- **Medium radius** (8pt) for cards, graph nodes
- **Large radius** (12pt) for sheets and modal panels
- **Full pill** only for tags and compact filters—not primary buttons (use macOS default button chrome)

### Elevation

macOS prefers **flat** UIs. OpenWrite uses:

1. **Spacing** (primary separator)
2. **Subtle shadow** on floating sheets only (`shadowFloating`)
3. **1px separators** (`separator`) between sidebar and content when needed

Avoid stacked drop shadows and Material-style blur panels except where AppKit requires vibrancy in the title bar (system-controlled).

---

## macOS native feel

### Human Interface Guidelines alignment

| HIG topic | OpenWrite approach |
|-----------|-------------------|
| **Navigation** | `NavigationSplitView` for sidebar + detail; optional tertiary inspector column |
| **Sidebars** | `.listStyle(.sidebar)`, SF Symbols, selection via List/Buttons |
| **Toolbars** | `ToolbarItem` groups: document actions left, view toggles right |
| **Settings** | `Settings` scene (`Cmd+,`) for vault path, AI endpoint, appearance |
| **Sheets** | `.sheet` for capture and import; `.alert` for destructive confirm |
| **Menus** | Commands for New Note, Quick Capture, Toggle Sidebar, Toggle Inspector |

### System integration

- **Accent color:** Respect `AccentColor` asset; map to `DesignTokens.Color.accent`.
- **Appearance:** Support Light, Dark, and Auto via `@Environment(\.colorScheme)`; tokens provide paired values.
- **Typography:** Prefer `Font` styles (`.body`, `.title`) over fixed sizes so Dynamic Type can scale where SwiftUI allows.
- **Keyboard:** Full menu command shortcuts; see [Accessibility.md § Keyboard](./Accessibility.md#keyboard).
- **Windowing:** Document-style windows optional in v2; v1 single main window with tabbed workbench inside.

### What “native” does not mean

- Blindly copying every Sonoma visual effect
- Replacing SwiftUI with AppKit for entire screens without cause
- Ignoring OpenWrite’s three-column workbench because Mail.app uses two columns

Native means **familiar affordances** (sidebar toggle, standard buttons, predictable shortcuts) on a layout tuned for notes + graph + AI.

---

## Layout grammar

### Workbench zones

```
┌──────────────┬────────────────────────────────────┬─────────────┐
│   Sidebar    │           Main content             │  Inspector  │
│   (nav)      │   (editor / graph / search / AI)   │  (context)  │
│   220–280pt  │           flex (min 480pt)         │  280–360pt  │
└──────────────┴────────────────────────────────────┴─────────────┘
```

| Zone | Min width | Max width | Collapsible |
|------|-----------|-----------|-------------|
| Sidebar | 220 | 280 | Yes (`Cmd+Ctrl+S`) |
| Main | 480 | — | No |
| Inspector | 280 | 360 | Yes (`Cmd+Option+I`) |

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

### Type scale

OpenWrite uses the **system font** (San Francisco) with semantic styles. Monospace is reserved for code blocks, block IDs in debug/citation chips, and vault paths in settings.

| Role | SwiftUI | Use |
|------|---------|-----|
| Document title | `.largeTitle.bold()` | Note H0 in editor |
| Section | `.title` / `.title2` / `.title3` | NDL headings |
| Body | `.body` | Paragraphs, list items |
| Secondary | `.callout` + `.secondary` | Timestamps, metadata |
| Caption | `.caption` | AI status, indexer progress |
| Code | `.system(.body, design: .monospaced)` | NDL code blocks |

Details: [Tokens.md § Typography](./Tokens.md#typography).

### UI copy voice

- **Sentence case** for headings and buttons (“Check connection”, not “Check Connection”)
- **No exclamation marks** in empty states
- **Error messages** include what failed and one recovery action
- **AI strings** attribute sources: “From *Meeting notes* · block `a1b2`”

---

## Iconography

### SF Symbols

Use **SF Symbols** exclusively for navigation and actions. Prefer outlined variants in sidebars; filled variants only for selected tab or emphasized toolbar item.

| Section | Symbol | Weight |
|---------|--------|--------|
| Notes | `doc.text` | regular |
| Graph | `point.3.connected.trianglepath.dotted` | regular |
| Search | `magnifyingglass` | regular |
| AI | `sparkles` | regular |
| Publish | `square.and.arrow.up` | regular |
| Vault locked | `lock.fill` | medium |
| Capture | `plus.circle` | regular |

Symbol scale: `.imageScale(.medium)` in sidebar; `.small` in compact inspector rows.

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

- Sidebar: system List selection + `textPrimary` / `textSecondary` per [Components.md § Sidebar](./Components.md#sidebar)
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

## Anti-patterns

Do **not**:

1. **Splash indexing gates** — block editing while “syncing” the entire vault (Reor anti-pattern).
2. **Full-screen AI** on launch — author-first requires editor or last document.
3. **Rainbow sidebar sections** — one accent, neutral structure.
4. **Custom scrollbars** — use system scroll views.
5. **Rounded “mobile” buttons** in the main toolbar — use `Button` styles `.bordered` / `.borderedProminent` per HIG.
6. **Copy Anytype** colors, illustrations, onboarding illustrations, or object-type iconography.
7. **Hard-coded `Color.red`** for non-destructive states — use `danger` token.
8. **Arbitrary animation** on every keystroke — motion budget in [Motion.md](./Motion.md).

---

## Governance

### Adding a new surface

1. Sketch zone placement (sidebar / main / inspector).
2. List required tokens; add to `Tokens.md` and `DesignTokens.swift` in one PR.
3. Document component in `Components.md` with states, shortcuts, VoiceOver.
4. Verify reduced motion and keyboard path.

### Review checklist

- [ ] Uses semantic tokens only
- [ ] Editor remains visually dominant for writing flows
- [ ] No network-required empty state
- [ ] VoiceOver labels on icon-only controls
- [ ] Animations use `Motion` durations and respect `accessibilityReduceMotion`

### References (external)

- [Apple Human Interface Guidelines — macOS](https://developer.apple.com/design/human-interface-guidelines/macos)
- [SwiftUI Documentation](https://developer.apple.com/documentation/swiftui)
- OpenWrite master plan: [../OpenWriteMasterPlan.md](../OpenWriteMasterPlan.md)

---

*End of OpenWrite Design Language v1.0*
