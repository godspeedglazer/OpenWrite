# OpenWrite UI Components

**Version:** 1.1  
**Implementation status:** Workbench shell + inspector AI panels + editor inline refine **scaffold** (`ContentView`, `WorkbenchInspectorView`, `ChatPanelView`, `RelatedNotesView`, `EditorView`, `InlineAssistController`). Refine uses a **sheet** today; **popover + Apply** is design target — [InlineAIEditing.md](./InlineAIEditing.md). Tabs, graph, capture sheet remain target-state.

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
8. [AI Chat panel](#ai-chat-panel)
9. [Inline assist](#inline-assist)
10. [Vault lock states](#vault-lock-states)
11. [Shared patterns](#shared-patterns)

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

- `WorkbenchState`: `selectedSection`, `sidebarVisible`, `inspectorVisible`, `inspectorTab`
- `VaultStore`: document list, selection, lock state
- `NavigationSplitView`: sidebar → `editorColumn` → detail (`WorkbenchInspectorView` when `inspectorVisible`)

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

Trailing **detail** column of `NavigationSplitView` for contextual tools: vault chat, semantic neighbors, and Past Writes. Implemented as `WorkbenchInspectorView` with `InspectorTab` segmented control. Author-first: inspector visible by default in v1 scaffold; user can hide via edge toggle.

Placement rationale (chat vs inline refine): [EditorAndAIPanel.md](./EditorAndAIPanel.md).

### Anatomy (implemented)

```
┌ Inspector ─────────────────────────────┐
│ [Chat] [Related] [Past Writes]         │  ← InspectorTab, .segmented
│ ─────────────────────────────────────  │
│  ChatPanelView | RelatedNotesView |    │
│  PastWritesTimelineView                │
└────────────────────────────────────────┘
```

### Specifications

| Property | Value | Code |
|----------|-------|------|
| Min width | 300pt | `WorkbenchInspectorView` |
| Ideal width | 340pt | same |
| Tab picker padding | 10pt horizontal | `.padding(10)` on `Picker` |
| Panel body | `maxWidth/Height: .infinity` | `Group` switch on `inspectorTab` |

### Inspector tabs (`InspectorTab`)

| Tab | Title | SF Symbol | View | Behavior |
|-----|-------|-----------|------|----------|
| `chat` | Chat | `bubble.left.and.bubble.right` | `ChatPanelView` | Vault-wide RAG Q&A; see [AI Chat panel](#ai-chat-panel) |
| `related` | Related | `link.circle` | `RelatedNotesView` | Semantic neighbors for **selected note**; debounced load |
| `pastWrites` | Past Writes | `clock.arrow.circlepath` | `PastWritesTimelineView` | Session timeline; filters by `selectedDocumentID` when set |

**Future tabs (not in enum today):** Outline (NDL headings), backlinks list, block properties — may merge with editor header or add segments without moving chat.

### Show / hide

| Control | Location | Behavior |
|---------|----------|----------|
| Inspector toggle | Right edge of `editorColumn` | `workbench.inspectorVisible`; `sidebar.right` / `sidebar.left` icon; 0.2s `easeInOut` |
| Hidden detail | `NavigationSplitView` detail | `Color.clear` 1pt placeholder |

### Tokens

| Element | Token |
|---------|-------|
| Panel title (per sub-view) | `.headline` |
| Segment control | system `.segmented` |
| Divider | system `Divider()` between chrome and body |
| Citation / source cards | `caption` / `caption2`, `secondary` @ 8% bg — see chat sources |

### States

| State | UI |
|-------|-----|
| Collapsed | Detail column minimal; editor uses full content width |
| Chat active | Default tab `inspectorTab == .chat` on fresh `WorkbenchState` |
| Related: no note | `ContentUnavailableView` — “No note selected” |
| Related: loading | Header `ProgressView` |
| Past Writes: filtered | When note selected, timeline shows that note’s sessions only |

### VoiceOver

- Inspector visibility announced when toggled (target)
- Related row: “{title}, related note, {score} percent, button”
- Chat sources: “Source, {documentTitle}, chunk {id prefix}”

### Code reference

`UI/Workbench/WorkbenchInspectorView.swift`, `InspectorTab.swift`, `WorkbenchState.swift`

---

## Note editor

### Purpose

Primary authoring surface for the open vault note. **`EditorView`** (implemented) uses **`SelectablePlainTextEditor`** (AppKit `NSTextView` bridge) synced to `VaultDocument.plainText`, with optional **rendered preview** of NDL blocks. Typed-page metadata (`PageTypeBadge`, `TypePickerView`, `PropertyInspectorView`) lives in the editor header—not the inspector.

**Inline refine:** header button **Refine selection** → `InlineAssistController` → result `.sheet` (read-only v1). See [Inline assist](#inline-assist).

Future: block-granular NDL editor with handles and slash commands; preview path already renders block kinds via `blockView`.

### Anatomy (implemented)

```
┌ EditorView ─────────────────────────────────────────────┐
│ [PageType badge]     [updatedAt] [Preview] [Refine selection]│
│  displayTitle (.largeTitle.bold)                          │
│  TypePickerView (switch type)                             │
│  PropertyInspectorView (rounded secondary bg)              │
│ ─────────────────────────────────────────────────────────  │
│  TextEditor (plain)  OR  ScrollView block preview        │
└──────────────────────────────────────────────────────────┘
```

| Region | Implementation |
|--------|----------------|
| Header chrome | `VStack` 24pt horizontal pad, 24pt top |
| Edit surface | `SelectablePlainTextEditor` + 12pt pad, 6% secondary background, 8pt corner radius |
| Refine | `Label("Refine selection", sparkles)`; disabled when `!canRefineSelection` or refining |
| Preview | `Toggle("Preview")`; `renderedPreview` iterates `rootBlocks` (excludes `.property`) |
| Missing doc | `ContentUnavailableView` — “Note missing” |

### Edit / sync behavior

| Event | Behavior |
|-------|----------|
| `onAppear` | `syncFromDocument` → load `plainText` into `@State editingText` |
| `onChange(editingText)` | `vaultStore.updatePlainText` + `pastWrites.recordEdit` |
| `onChange(document.updatedAt)` | Re-sync from store if external change and not in preview mode |
| `onChange(documentID)` | Re-sync when selection changes |

### Block types (preview — `blockView`)

| Kind | Rendering |
|------|-----------|
| `heading1–3` | `.title` / `.title2` / `.title3` |
| `paragraph` | `Text(block.text)` |
| `bullet` | `•` + text |
| `quote` | Leading 3pt bar + text |
| `code` | Monospaced + 12% secondary background |
| `wikilink` | `.foregroundStyle(.tint)` |
| `divider` | `Divider()` |
| `property` | Capsule chip (also in header inspector) |

### Tokens (current vs target)

| Element | Current | Target token |
|---------|---------|--------------|
| Editor field bg | `Color.secondary.opacity(0.06)` | `codeBackground` / `surface` |
| Property strip | 6% secondary, 10pt radius | `surface` + `Radius.medium` |
| Title | `.largeTitle.bold` | `documentTitle` |

### States

| State | UI |
|-------|-----|
| No selection (parent) | `ContentView` shows “Select a note” |
| Note missing | `ContentUnavailableView` in `EditorView` |
| Edit mode | `TextEditor` focused; commits on change |
| Preview mode | Read-only block column; edits paused until toggle off |
| Read-only vault (future) | Disable `TextEditor`; banner |

### Keyboard (target + partial)

| Shortcut | Action | Status |
|----------|--------|--------|
| `Cmd+Shift+P` | Toggle preview (proposed) | Toggle in header only today |
| `Cmd+B` / `Cmd+K` | Rich text / wikilink | NDL editor v2 |
| Inline refine | Selection popover | [InlineAIEditing.md](./InlineAIEditing.md) |

### VoiceOver

- Title: static `Text` today — future editable field
- Preview toggle: “Preview, switch”
- `SelectablePlainTextEditor`: “Note body, text field”

### Code reference

`UI/EditorView.swift`, `UI/Types/PropertyInspectorView.swift`, `PageTypeBadge`

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

## AI Chat panel

### Purpose

**Vault chat:** local RAG over indexed note chunks, streamed answers with **source cards**, in the inspector **Chat** tab. Implemented as `ChatPanelView` + `ChatPanelModel`. Semantic **related notes** are a **separate tab** (`RelatedNotesView`) — do not combine into one scrolling panel.

State machine: [AIActivityStates.md](./AIActivityStates.md). Placement: [EditorAndAIPanel.md](./EditorAndAIPanel.md).

### Anatomy (implemented)

```
┌ Vault chat ──────────────────────────────┐
│ Vault chat          [status]  [Clear]    │  ← header
│ ───────────────────────────────────────  │
│  (empty) ContentUnavailableView          │
│  OR message bubbles (LazyVStack)         │
│     user: trailing, accent 18% bg        │
│     assistant: leading, secondary 12% bg │
│     sources: up to 6 RetrievalHit cards  │
│ ───────────────────────────────────────  │
│ [Ask about your notes…]  [arrow.up]      │  ← composer
└──────────────────────────────────────────┘
```

### Message model (`ChatMessage`)

| Field | Use |
|-------|-----|
| `role` | `.user` \| `.assistant` \| `.system` |
| `text` | Bubble content; selectable |
| `sourceHits` | Shown under assistant after `buildContext` |
| `isStreaming` | Placeholder `…` when empty and streaming |

### Header

| Element | Behavior |
|---------|----------|
| Title | “Vault chat” `.headline` |
| `statusLine` | Caption: “Retrieving context…”, “{n} sources”, “No indexed matches”, “Error” |
| Clear | Cancels stream task; disabled when `messages.isEmpty` |

### Composer

| Element | Spec |
|---------|------|
| Field | `TextField` multiline 1–4 lines, rounded border, placeholder “Ask about your notes…” |
| Send | `arrow.up.circle.fill` title2; disabled when `isBusy` or invalid draft |
| Submit | `onSubmit` + `Cmd+Return` |
| Sanitization | `AIInput.sanitizeQuery` before send |

### Sources block

Under assistant messages with hits (max 6):

- Title row: `documentTitle` (caption semibold)
- Snippet: 2 lines, secondary
- Chunk id: `chunk:{uuid prefix}…` monospaced tertiary
- Card: 6pt pad, 8% secondary background, 6pt radius

**Future:** tap source → open note + scroll to chunk.

### Related notes tab (same inspector, different view)

Not part of `ChatPanelView` — documented here for contrast.

| Element | `RelatedNotesView` |
|---------|------------------|
| Header | “Related notes” + loading spinner |
| Rows | Title, `score` as `NN%`, snippet 3 lines |
| Action | Tap → `vaultStore.selectedDocumentID = hit.documentID` |
| Trigger | Debounced on selection + `indexedChunkCount` change |

### Tokens

| Element | Current |
|---------|---------|
| User bubble | `accentColor.opacity(0.18)` |
| Assistant bubble | `secondary.opacity(0.12)` |
| System bubble | `orange.opacity(0.12)` (reserved) |
| Source card | `secondary.opacity(0.08)` |

### States

Full diagram: [AIActivityStates.md](./AIActivityStates.md).

| State | UI |
|-------|-----|
| Empty | `ContentUnavailableView` — “Ask your vault” / sparkles |
| Retrieving | `statusLine` + assistant `…` |
| Streaming | Growing assistant text; scroll to latest |
| Error | Error string in bubble; header “Error” |
| Busy | Send disabled |

**LM Studio / index:** sidebar `Section("AI")` in `ContentView` — URL, model, status, chunk count, Check connection, Rebuild index. Target: disable send when unreachable.

### Privacy copy (target)

Static footnote in chat footer: “Queries stay on this Mac. Nothing is sent except to your configured LM Studio endpoint.”

### VoiceOver

- Empty: system `ContentUnavailableView` labels
- Messages: enable `.textSelection(.enabled)` for review
- Send: “Send question, button”

### Code reference

`UI/AI/ChatPanelView.swift`, `AI/RAGService.swift`, `AI/OpenWriteAIServices.swift`

---

## Inline assist

### Purpose

**Selection refine** in the editor column — not inspector chat. Implemented via `InlineAssistController` + `SelectablePlainTextEditor`. **Design target:** popover at selection with Apply; **shipped v1:** toolbar button + result sheet (read-only). Full spec: [InlineAIEditing.md](./InlineAIEditing.md). Placement: [EditorAndAIPanel.md](./EditorAndAIPanel.md).

### Anatomy (implemented)

| Step | Behavior |
|------|----------|
| Select text | `textViewDidChangeSelection` → debounced `scheduleSelectionCapture` (0.4s) |
| Valid snapshot | `latestSnapshot` set; **Refine selection** enabled |
| Tap refine | `refineSelection(using: aiServices.rag)`; sheet opens; `phase = .refining` |
| Complete | `ready(text)` or `failed(message)` in sheet |
| Done | `dismissRefine()` — does not merge text into note yet |

### v1 scope

| In scope (shipped) | Target (next) |
|--------------------|---------------|
| Selection debounce + char cap | Popover vs sheet |
| Async refine (`BuiltInAgents.refineProse`) | **Apply** replaces `selectedRange` |
| Result sheet, selectable text | Preset chips + custom instruction |
| Non-blocking editor | Context menu entry |

| Out of scope | |
|--------------|--|
| Multi-turn refine thread | Vault-wide RAG in refine flow |
| Floating global chat bubble | |

### States

`InlineAssistPhase`: idle → refining → ready \| failed. Diagram: [InlineAIEditing.md](./InlineAIEditing.md).

### Code reference

`UI/Editor/InlineAssistController.swift`, `UI/EditorView.swift` (`refineResultSheet`)

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

- [x] Three-column `NavigationSplitView` with inspector (`ContentView`)
- [x] Inspector tabs: Chat, Related, Past Writes (`WorkbenchInspectorView`)
- [x] `ChatPanelView` RAG streaming + sources
- [x] `EditorView` plain-text edit + NDL preview toggle
- [ ] `SidebarSection` drives main column switch (notes / graph / search)
- [ ] Token migration in `EditorView` and `ContentView` → `DesignTokens`
- [ ] Capture sheet UI wired to `QuickCaptureController`
- [ ] Graph view stub with design tokens
- [ ] Vault lock full-screen gate
- [x] Inline refine scaffold ([InlineAIEditing.md](./InlineAIEditing.md))
- [ ] Refine popover + Apply merge into selection
- [ ] Chat: stop button + LM unreachable disables send

---

*See also: [EditorAndAIPanel.md](./EditorAndAIPanel.md) · [AIActivityStates.md](./AIActivityStates.md) · [InlineAIEditing.md](./InlineAIEditing.md) · [Tokens.md](./Tokens.md) · [Accessibility.md](./Accessibility.md) · [Motion.md](./Motion.md)*
