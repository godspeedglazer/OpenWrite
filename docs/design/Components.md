# OpenWrite UI Components

**Version:** 1.0  
**Implementation status:** Partial — scaffold in `UI/`; this spec is target-state for E-08 Workbench shell and related epics.

Each component lists **anatomy**, **tokens**, **states**, **keyboard**, and **VoiceOver** expectations. Build with SwiftUI; use AppKit bridges only for text editing performance when NDL editor v1 requires it.

---

## Table of contents

1. [Workbench shell](#workbench-shell)
2. [Sidebar](#sidebar)
3. [Workbench tabs](#workbench-tabs)
4. [Inspector](#inspector)
5. [Note editor](#note-editor)
6. [Capture sheet](#capture-sheet)
7. [Graph view](#graph-view)
8. [AI panel](#ai-panel)
9. [Vault lock states](#vault-lock-states)
10. [Shared patterns](#shared-patterns)

---

## Workbench shell

### Purpose

Root container hosting sidebar navigation, primary content, and optional inspector. Evolves from current `ContentView` + `NavigationSplitView` to a three-column **AFFiNE-inspired** shell without importing AFFiNE code: tabs inside the main column, section switching via `SidebarSection`.

### Anatomy

```
┌─ Titlebar (system) ─────────────────────────────────────────────┐
│ Toolbar: [sidebar] [tabs…………] [inspector] [capture] [search]   │
├──────────┬─────────────────────────────────────┬────────────────┤
│ Sidebar  │  Tab content (Editor / Graph / …)   │   Inspector    │
└──────────┴─────────────────────────────────────┴────────────────┘
```

### Data

- `WorkbenchState`: `selectedSection`, `sidebarVisible`, `inspectorVisible` (future)
- `VaultStore`: document list, selection, lock state

### Tokens

| Element | Token |
|---------|-------|
| Window bg | `Color.background` |
| Toolbar | system + `Spacing.spacing2` item gaps |
| Split separators | `Color.separator` |

### States

| State | Behavior |
|-------|----------|
| Initial launch | Unlock vault if needed; restore last section + document |
| No vault | `ContentUnavailableView` → create/open vault |
| Narrow window | Collapse inspector &lt; 900pt total width |

### Keyboard

| Shortcut | Action |
|----------|--------|
| `Cmd+Ctrl+S` | Toggle sidebar |
| `Cmd+Option+I` | Toggle inspector |
| `Cmd+1…5` | Select sidebar section (Notes, Graph, Search, AI, Publish) |

---

## Sidebar

### Purpose

Primary navigation: vault notes list, section switcher (Notes / Graph / Search / AI / Publish), and compact AI connection status in v1 scaffold.

### Anatomy

```
┌ Sidebar ─────────────┐
│ [Section picker]     │  ← icon+label or segmented control
│ ─────────────────    │
│ VAULT                │  ← sidebarSection header
│   📄 Note title      │
│   📄 Daily …         │
│ ─────────────────    │
│ AI                   │
│   LM Studio URL      │
│   Status caption     │
│   [Check connection] │
└──────────────────────┘
```

### Specifications

| Property | Value |
|----------|-------|
| Style | `.listStyle(.sidebar)` |
| Min width | `Layout.sidebarMinWidth` (220) |
| Row height | 28–32pt (system default) |
| Selection | Single document ID; `Button` + `.plain` or `List(selection:)` |

### Tokens

| Element | Token |
|---------|-------|
| Background | `Color.background` (sidebar uses window bg) |
| Section header | `Typography.sidebarSection`, `textSecondary` |
| Row title (selected) | `textPrimary` |
| Row title (default) | `textSecondary` |
| Row hover | `Opacity.overlayLight` on `surface` |

### States

| State | UI |
|-------|-----|
| Empty vault | “No notes yet” — `textSecondary`, `caption` |
| Loading documents | `ProgressView` inline, 1 row |
| Selected doc | Primary foreground + system selection highlight |
| Vault locked | Sidebar disabled; show lock overlay — [Vault lock states](#vault-lock-states) |

### Interactions

- **Click** row → select document, load editor in main column
- **Double-click** → optional rename inline (v2)
- **Context menu** → Duplicate, Delete, Reveal in Finder (encrypted blob path stub)

### VoiceOver

- Section headers: `accessibilityAddTraits(.isHeader)`
- Row: “{title}, note, {n} of {total}”
- AI status: “LM Studio, {status}”

### Code reference (current)

`ContentView.sidebar` uses `List` + `Section("Vault")` — align styling with tokens when refactoring.

---

## Workbench tabs

### Purpose

Allow multiple documents (or views) open in the main column, similar to browser tabs but calmer: native macOS segmented control or tab bar under toolbar.

### Anatomy

```
[ Meeting notes × ] [ Graph · global × ] [ + ]
────────────────────────────────────────────────
│           Active tab content                 │
```

### Specifications

| Property | Value |
|----------|-------|
| Tab height | 32pt |
| Active indicator | 2pt bottom bar `Color.accent` |
| Inactive label | `textSecondary` |
| Close button | `xmark` SF Symbol, 16pt hit target |
| New tab | `plus` — creates untitled note or section default |

### States

| State | UI |
|-------|-----|
| Active | `textPrimary`, accent underline |
| Dirty (unsaved) | Dot `•` before title — `warning` at 80% size |
| Pinned | `pin.fill` icon; no close on hover (optional v2) |

### Keyboard

| Shortcut | Action |
|----------|--------|
| `Cmd+T` | New tab (note) |
| `Cmd+W` | Close tab |
| `Ctrl+Tab` | Next tab |

### Motion

Tab insert/remove: `Motion.durationFast` — see [Motion.md](./Motion.md).

---

## Inspector

### Purpose

Trailing column for **context**: outline, backlinks, related notes, AI chat, block properties. Author-first: collapsed by default for new users until they open AI or backlinks.

### Anatomy

```
┌ Inspector ────────────────┐
│ [Outline] [Links] [AI]    │  ← segmented picker
│ ─────────────────────────  │
│  (panel content)           │
│                            │
└────────────────────────────┘
```

### Specifications

| Property | Value |
|----------|-------|
| Width | 280–360pt resizable |
| Background | `Color.surface` |
| Padding | `Spacing.inspectorPadding` |
| Segment control | standard macOS picker |

### Panels

| Panel | Contents |
|-------|----------|
| **Outline** | NDL heading tree, jump-to-block |
| **Links** | Backlinks + outgoing wikilinks |
| **AI** | Related notes, Q&A, citations |
| **Properties** | Created, modified, tags (v2) |

### Tokens

| Element | Token |
|---------|-------|
| Panel title | `Typography.callout` + `textSecondary` |
| Citation chip | `codeSmall`, `surfaceElevated`, `Radius.small` |
| Divider | `separator` |

### States

| State | UI |
|-------|-----|
| Collapsed | Main column expands; toggle via toolbar |
| Empty (no note) | “Select a note for details” |
| AI loading | Streaming text + stop button (`danger` on stop optional) |

### VoiceOver

- Inspector visibility announced when toggled
- Citation links: “Citation from {note}, block {id}”

---

## Note editor

### Purpose

Primary authoring surface for NDL block trees. Current `EditorView` renders a read-oriented column; editor v1 adds focus, block handles, and slash commands.

### Anatomy

```
┌ Main (editor) ────────────────────────────────┐
│  Document title (editable)                     │
│  ───────────────────────────────────────────  │
│  ## Heading                                    │
│  Paragraph text…                               │
│  • Bullet                                      │
│  > Quote                                       │
│  `code block`                                  │
│  [[Wikilink]]                                  │
└────────────────────────────────────────────────┘
        max-width 720pt centered
```

### Block types (NDL)

| Kind | Typography | Extra chrome |
|------|------------|--------------|
| `heading1–3` | `heading1`–`heading3` | — |
| `paragraph` | `body` | — |
| `bullet` | `body` + bullet glyph | `spacing2` HStack |
| `quote` | `body` | 3pt leading bar `separator` |
| `code` | `code` | `codeBackground`, `Radius.small`, `spacing2` pad |
| `wikilink` | `body` | `wikilink` color |
| `divider` | — | `Divider()` |

### Tokens

| Element | Token |
|---------|-------|
| Outer pad | `editorPadding` |
| Block gap | `spacing3` |
| Title | `documentTitle` |
| Focus ring | `accent` @ 40%, 2pt |

### States

| State | UI |
|-------|-----|
| Empty document | Placeholder title “Untitled” — `textTertiary` |
| Block focused | Subtle `accentMuted` row background |
| Read-only (locked vault) | No caret; banner above title |

### Keyboard

| Shortcut | Action |
|----------|--------|
| `Cmd+B` | Bold (when rich text supported) |
| `Cmd+K` | Insert wikilink |
| `Cmd+Enter` | Toggle heading level (stub) |
| `Option+↑/↓` | Move block (v2) |

### VoiceOver

- Title: “Document title, text field”
- Block: “Heading level 2, {text}” / “Bullet, {text}”

### Code reference

See `EditorView.blockView` — migrate colors to `DesignTokens`.

---

## Capture sheet

### Purpose

**Fast capture** (E-09): global shortcut opens a compact sheet to append to daily note or inbox without leaving current context.

### Anatomy

```
        ┌ Capture ──────────────────────┐
        │  Quick capture                 │
        │  ┌──────────────────────────┐  │
        │  │ Type thought…            │  │
        │  └──────────────────────────┘  │
        │  Append to: [Daily ▼]          │
        │           [Cancel]  [Save]     │
        └────────────────────────────────┘
```

### Specifications

| Property | Value |
|----------|-------|
| Presentation | `.sheet` or `NSPanel` floating (product decision) |
| Width | `Layout.captureSheetWidth` (520) |
| Corner | `Radius.large` |
| Shadow | `Shadow.floating` |
| Field | multiline `TextEditor`, min 3 lines |

### Tokens

| Element | Token |
|---------|-------|
| Sheet bg | `surfaceElevated` |
| Field bg | `surface` |
| Primary action | `.borderedProminent` + `accent` |
| Cancel | `.bordered` |

### States

| State | UI |
|-------|-----|
| Empty save | Disable Save button |
| Saving | Progress on Save, disable field |
| Success | Dismiss + optional subtle “Captured” in parent toolbar |

### Keyboard

| Shortcut | Action |
|----------|--------|
| `Cmd+Shift+N` | Open capture (global when app active) |
| `Enter` | Save (with Cmd) |
| `Esc` | Dismiss |

### Controller

`QuickCaptureController`: `isPresented`, `draftText`, `commit(into:)`.

### VoiceOver

- “Quick capture, text area”
- Save: “Save to daily note”

---

## Graph view

### Purpose

Visualize note connectivity (backlinks, wikilinks). P0 epic E-06; native SwiftUI `Canvas` or SpriteKit only if needed for scale.

### Anatomy

```
┌ Graph ────────────────────────────────────────┐
│  [Filter: All ▼]  [zoom + -]                  │
│         ○───○                                 │
│          \ /                                  │
│           ○  selected (accent ring)           │
└───────────────────────────────────────────────┘
```

### Node

| Property | Value |
|----------|-------|
| Min size | 44×44 pt |
| Fill | `graphNode` |
| Label | `caption`, max 24 chars ellipsis |
| Stroke (focused) | `graphNodeFocused`, 2pt |
| Stroke (default) | `separator`, 1pt |

### Edge

| Property | Value |
|----------|-------|
| Color | `graphEdge` |
| Width | 1pt; 2pt when endpoint selected |
| Style | solid; dashed for weak links (optional) |

### Interactions

- **Click** node → select note, optional open in editor
- **Drag** pan canvas
- **Scroll** zoom (pinch + modifier)
- **Hover** tooltip: note title + link count

### States

| State | UI |
|-------|-----|
| Empty graph | “Create links with [[wikilinks]]” |
| Layout computing | Centered `ProgressView` |
| Selected | Inspector shows link list |

### Motion

Node focus: `durationFast` scale 1.0 → 1.05; respect reduced motion — [Motion.md](./Motion.md).

### Performance

Cap visible nodes (e.g. 200) with “Show more” — calm beats flashy physics.

---

## AI panel

### Purpose

Local RAG and LM Studio Q&A in the inspector **AI** segment. Human remains author; panel shows retrieval and citations.

### Anatomy

```
┌ AI ─────────────────────────┐
│ Related notes               │
│  • Meeting notes (0.82)     │
│  • Research brief (0.71)    │
│ ─────────────────────────── │
│ Ask your vault              │
│ ┌─────────────────────────┐ │
│ │ Question…               │ │
│ └─────────────────────────┘ │
│ [Ask]                       │
│ ─────────────────────────── │
│ Answer stream…              │
│ [1] Meeting notes ¶3        │
└─────────────────────────────┘
```

### Specifications

| Element | Spec |
|---------|------|
| Related row | `callout`, chevron, relevance score `caption` `textTertiary` |
| Input | `TextField` or `TextEditor` 2–4 lines |
| Ask button | `.borderedProminent`, disabled when LM unreachable |
| Citation | `codeSmall` chip, click jumps to block |
| Streaming | Typewriter with 16ms throttle max; no flashy cursor |

### Tokens

| Element | Token |
|---------|-------|
| Panel bg | inherits `surface` |
| Citation chip bg | `accentMuted` |
| Error | `danger` caption |
| Connection ok | `success` dot 6pt |

### States

| State | UI |
|-------|-----|
| LM Studio checking | “Checking…” `caption` |
| Reachable | “Reachable” `success` |
| Unreachable | “Unreachable” + retry; Ask disabled |
| Streaming | Stop button visible |
| Empty vault | “Add notes to enable related documents” |

### Privacy copy

Static footnote: “Queries stay on this Mac. Nothing is sent except to your configured LM Studio endpoint.”

### VoiceOver

- Related list: “Related note, {title}, relevance {percent}”
- Citation: “Source, {title}, block {id}, button”

### Code reference

`ContentView` AI section + `LMStudioClient` — migrate to inspector panel.

---

## Vault lock states

### Purpose

Communicate encryption state clearly without fearmongering. Tied to E-01 Vault encryption v1.

### States matrix

| State | Screen | Primary action |
|-------|--------|----------------|
| **No vault** | Welcome | Create vault / Open vault |
| **Locked** | Lock screen | Password / Touch ID unlock |
| **Unlocking** | Progress | Cancel (if &gt; 3s) |
| **Unlocked** | Workbench | Lock vault (menu) |
| **Unlock failed** | Alert | Retry, reset warning |
| **Keychain denied** | Alert | Open System Settings |

### Lock screen anatomy

```
┌─────────────────────────────────────┐
│         lock.fill (large)           │
│         OpenWrite                   │
│    Enter password to unlock         │
│    ┌─────────────────────────┐      │
│    │ ••••••••                │      │
│    └─────────────────────────┘      │
│    [ Unlock ]  Touch ID icon          │
│    caption: Vault: ~/…/MyVault.ow    │
└─────────────────────────────────────┘
```

### Tokens

| Element | Token |
|---------|-------|
| Icon | `textSecondary`, 48pt |
| Title | `documentTitle` |
| Field | standard secure field |
| Error shake | `danger` border; motion `durationFast` unless reduced |
| Success | crossfade to workbench `durationStandard` |

### Sidebar when locked

Disabled opacity 0.5; no pointer events; `accessibilityLabel`: “Vault locked”.

### VoiceOver

- Unlock field: “Vault password, secure text field”
- Touch ID: “Unlock with Touch ID, button”

---

## Shared patterns

### Empty states

Use `ContentUnavailableView` with SF Symbol, title, description, optional action button. Vertical padding `spacing10`.

### Progress

- **Inline** for section status (AI, indexer)
- **Bar** under toolbar for long operations
- Never block editor unless vault is locked

### Context menus

System `contextMenu` with destructive actions last, `role: .destructive`.

### Search field (future)

`.searchable` on Graph/Notes with `Typography.body`; results use `accent` for match highlight background at 20% opacity.

---

## Implementation checklist (E-08)

- [ ] Three-column `NavigationSplitView` with inspector
- [ ] `SidebarSection` drives main column switch
- [ ] Token migration in `EditorView` and `ContentView`
- [ ] Capture sheet UI wired to `QuickCaptureController`
- [ ] Graph view stub with design tokens
- [ ] Vault lock full-screen gate

---

*See also: [Tokens.md](./Tokens.md) · [Accessibility.md](./Accessibility.md) · [Motion.md](./Motion.md)*
