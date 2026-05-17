# Agent prompt — OpenWrite full UI refactor

Copy everything below the line into a **new Cursor agent** (Agent mode) at the OpenWrite repo root. Do not commit unless the user asks.

---

## Mission

Refactor OpenWrite’s **entire product UI** to **Anytype-level polish and cohesion** (density, filled surfaces, calm rail, editorial typography, object-row quality) while **never copying Anytype code** (ASAL) or shipping their Electron framework.

OpenWrite is **writing-first, AI-second**. The editor column is the hero; local AI is a secondary inspector strip. Backend/RAG completeness is **out of scope** for this mission unless a tiny UI hook requires a stub fix.

**Workspace:** `/Users/erichspringer/Downloads/OpenWrite`  
**Shipping code only:** `OpenWrite/OpenWrite/` and `OpenWrite/OpenWrite.xcodeproj`  
**Do not modify:** `reor-main/`, `logseq-master/`, `AFFiNE-canary/`, `anytype-ts-develop/`, `massCode-main/`, `rem-main/`, `buffer/`, or any other gitignored vendor tree.

---

## Read first (in order)

1. **[HANDOFF.md](./HANDOFF.md)** — honest current state, broken list, commits, build steps.
2. **[docs/ProductDirection.md](docs/ProductDirection.md)** — writing-first layout, reference screenshots table, competitor roles.
3. **[docs/design/ProductDirection.md](docs/design/ProductDirection.md)** — UI non-negotiables.
4. **[docs/design/FrontendPriorities.md](docs/design/FrontendPriorities.md)** — P0 checklist and sequencing.
5. **[docs/design/AntiPatterns.md](docs/design/AntiPatterns.md)** — forbidden patterns (reject PRs that violate).
6. **[docs/design/OpenWriteDesignLanguage.md](docs/design/OpenWriteDesignLanguage.md)** — visual system.
7. **[docs/design/OWComponents.md](docs/design/OWComponents.md)** — component specs.
8. **[docs/design/Typography.md](docs/design/Typography.md)** — serif stack, `UIAppFonts`.
9. **[docs/design/OWIcons.md](docs/design/OWIcons.md)** — Lucide/Phosphor direction.
10. **[docs/design/EditorAndAIPanel.md](docs/design/EditorAndAIPanel.md)** — proportions, inspector collapse.
11. **[docs/design/AnytypeUIInspiration.md](docs/design/AnytypeUIInspiration.md)** — clean-room patterns only.
12. **[BUGFIXES.md](./BUGFIXES.md)** — do not regress theme/intro/vault/graph fixes.

### Reference screenshots

Use the captures linked in **ProductDirection § Reference captures** (Cursor workspace assets). If missing locally, ask the user to re-attach or copy into `docs/assets/product-direction/`. Compare side-by-side after each phase.

---

## Non-negotiables

| Rule | Implementation hint |
|------|---------------------|
| **Editor ≥ 55%** of content width at default window | `AnytypeShellView` center column `layoutPriority`; collapse AI strip by default |
| **AI strip collapsed by default** | `WorkbenchState.aiAssistExpanded == false` on fresh launch |
| **Inspector cap** | ≤ `DesignTokens.Layout.assistStripMaxWidth` (~360pt) |
| **LM Studio in Settings** | Not a dominant left-rail section |
| **OWNavigationRail** | Custom rail — not system `List` + blue selection |
| **Section order** | OBJECTS → DATABASES → VAULT (serif small-caps labels) |
| **Serif typography** | Source Serif 4 via `OWTypography`; **no warning banner** in release-quality build |
| **Open icons** | `OWUnicodeIcon` / `OWIcon` — **zero** `Image(systemName:)` in product UI |
| **No custom broken Path icons** | Do not reintroduce hand-drawn SF-like paths |
| **One brand accent** | `DesignTokens.Color.accent` — not `accentColor` prominent buttons |
| **Bloom intro** | 0.35–0.45s max; no multi-second splash |
| **Filled empty states** | `OWPageHero` + “+ New row” / type sheet — not lone placeholder paragraphs |
| **Flat editor canvas** | `editorCanvas` token — no vibrancy stack in body |

---

## Anti-patterns (do not ship)

- `NavigationSplitView` sidebar as stock `List` with HIG selection blue.
- `Form` / grouped `Section` as the **center column** main layout.
- SF Symbols, `ContentUnavailableView` with system images.
- Inspector half the window; vault chat as landing.
- LM Studio configuration block above vault list in the rail.
- Inter/SF-only chrome with no serif voice.
- Copying Anytype TS, assets, hex values, or strings from `anytype-ts-develop/`.
- Editing vendor reference folders.
- Drive-by backend epics (encryption, LanceDB, sync).
- Replacing `DesignTokens` color names with ad hoc `Color.red` / `.blue`.
- Theme changes that `.id()` the root window and replay intro (see BUGFIXES.md).

---

## Phased plan

Execute in order. After each phase: `xcodebuild -scheme OpenWrite -configuration Debug build`, run app, compare to Anytype captures.

### Phase 1 — Shell & layout geometry

**Files (primary):** `UI/Shell/AnytypeShellView.swift`, `OWNavigationRail.swift`, `WorkbenchState.swift`, `CenterWorkbenchTab.swift`, `ContentView.swift`, `LaunchIntroView.swift`, `DesignTokens.swift` (Layout).

**Goals:**

- Three-zone mental model: **rail (~240pt) | editor (flex, min ~480pt) | assist (0 or ≤360pt)**.
- AI assist **collapsed** on launch; toggle preserves editor width.
- Remove any remaining HIG-default split chrome that reads “Apple utility.”
- Window resize: collapse assist first, then rail (document in `docs/design/LayoutAndResize.md`).
- Bloom intro timing and theme observation (keep BUGFIXES behavior).

**Acceptance:**

- Default 1280×800: editor visually dominates; no equal three columns.
- Toggling theme does not reset vault selection or replay intro.

---

### Phase 2 — Header, hero, page chrome

**Files:** `OWPageHeaderEditor.swift`, `OWPageHero.swift`, `OWPageBanner.swift`, `OWMetadataChip.swift`, `OWObjectTypeChip.swift`, `CoverStyle.swift`, `EditorView.swift`.

**Goals:**

- Anytype-like **page hero**: icon, title (editable), metadata row, optional gradient `OWPageBanner`.
- Move type/property **noise** out of center-only grids into header + compact chips.
- **Fix Source Serif loading** so `OWTypography.isBundledSerifAvailable == true` and **remove persistent warning banner** from normal use (banner only in debug if desired).
- Title uses display serif; metadata uses label styles from tokens.

**Acceptance:**

- No yellow “Source Serif 4 did not load” banner in standard Debug build after clean build.
- New page flow feels like creating an **object**, not filling a Settings form.

---

### Phase 3 — Block editor & center column fill

**Files:** `OWBlockEditorView.swift`, `OWPreviewBlockRow.swift`, `EditorView.swift`, `InlineAssistController.swift`, `NoteBlock.swift`, `NDLParser.swift` (display only).

**Goals:**

- Fix **layout glitches**: consistent vertical rhythm, padding, focus ring, block gutters.
- Filled column: callouts as `OWRoundedRect(.elevated)` where spec’d; reduce dead margin.
- Inline assist: selection-anchored popover (refine / apply) — **not** a second full chat column.
- Wikilink styling readable; code blocks use `OWTypography.code*` only.

**Acceptance:**

- Ten-block page scrolls without overlapping rows or clipped bullets.
- Empty document shows hero + CTA, not a void.

**Out of scope:** Full Logseq outliner (indent/outdent, slash menu) — polish existing blocks only.

---

### Phase 4 — Sidebar & databases

**Files:** `OWSidebarRow.swift`, `OWSidebarSection.swift`, `DatabaseListView.swift`, `DatabaseTableView.swift`, `CreateDatabaseSheet.swift`, `TypePickerView.swift`.

**Goals:**

- Rail: rounded white **blocks** on gray (`sidebarBackground`), pill selection, dense rows with Unicode/Lucide icons.
- Database table: empty schema state, row editor sheet lifecycle (keep BUGFIXES).
- Object type colors from `ObjectType` / tokens — not washed system blue.

**Acceptance:**

- Sidebar matches Anytype graph capture **density** (not pixel-perfect clone).
- Creating a database and row feels native to OpenWrite tokens.

---

### Phase 5 — Graph tab

**Files:** `GraphView.swift`, `GraphViewModel.swift`, `GraphPlaceholderView.swift`.

**Goals:**

- Preserve **932e576** fixes (rect nodes, edges, spacing, all docs).
- Polish chrome: floating stats bar, isolated count, pan/zoom reset on vault change.
- Graph as **navigation surface** — secondary to editor, not default home tab.

**Acceptance:**

- 20+ note vault: readable graph, tap opens editor, no giant overlapping cards.
- “No links yet” overlay when edges empty but nodes exist.

---

### Phase 6 — AI strip & settings

**Files:** `AIAssistStripView.swift`, `AIAssistNavigationState.swift`, `OWAIPanelHeader.swift`, `ChatPanelView.swift`, `RelatedNotesView.swift`, `PastWritesTimelineView.swift`, `AISettingsView.swift`, `OpenWriteSettingsView.swift`.

**Goals:**

- Strip: back stack via `OWAIPanelHeader`; tabs Chat | Related | Past Writes.
- Copy and errors **local-first** (“LM Studio unreachable at …”) not generic failures.
- Settings owns model URL, ingestion health, theme picker.
- Related notes list uses tokens (already partially done).

**Acceptance:**

- User can write full screen with assist hidden.
- Opening assist does not shrink editor below `editorMinWidth`.

---

## Acceptance criteria (mission complete)

All must pass in **Debug** build on macOS 14+:

1. **Grep gate:** no `Image(systemName:)`, `systemImage`, or `Label(..., systemImage:)` in `OpenWrite/OpenWrite/**/*.swift` except documented test/debug files (ideally zero).
2. **Grep gate:** no bare `Font.body` / `.title` system styles in product UI (use `DesignTokens.Typography` / `OWTypography`).
3. **Serif:** bundled Source Serif 4 loads; no user-visible font warning in normal run.
4. **Layout:** editor ≥ 55% width at default size; AI strip collapsed on launch.
5. **Rail:** custom `OWNavigationRail` — not stock blue `List` IA.
6. **Icons:** Unicode/open set only — no broken Path icons, no SF Symbols.
7. **Graph:** rect nodes + edges from 932e576 still work; polish acceptable.
8. **Build:** `xcodebuild -scheme OpenWrite -configuration Debug build` succeeds.
9. **Visual:** side-by-side with Anytype About + Graph reference captures — same **family** of density (user judges “would download”).
10. **Scope:** zero files changed under vendor/reference directories.

---

## Suggested file touch map

```
OpenWrite/OpenWrite/
  Design/DesignTokens.swift
  Design/OWTypography.swift
  UI/Shell/*
  UI/Design/*
  UI/Editor/*
  UI/Graph/*
  UI/Database/*
  UI/AI/*
  UI/Workbench/*
  UI/Settings/*
  App/OpenWriteApp.swift
```

Avoid unrelated changes to `Core/Crypto`, `IngestionPipeline` internals unless required for UI compile.

---

## Verification commands

```bash
cd /Users/erichspringer/Downloads/OpenWrite/OpenWrite
xcodebuild -scheme OpenWrite -configuration Debug build

# Anti-pattern grep (expect no matches in UI):
rg 'systemName:|systemImage:' OpenWrite/OpenWrite --glob '*.swift'
rg 'Font\.body|\.font\(\.body\)' OpenWrite/OpenWrite --glob '*.swift'
```

Run the app (⌘R in Xcode). Walkthrough:

1. Launch → Bloom → workbench.
2. Create page → edit title → add blocks → paste image if supported.
3. Toggle theme → selection preserved.
4. Open graph → tap node → editor.
5. Open database → empty schema message.
6. Toggle AI strip → chat → back navigation.
7. Settings → LM Studio URL visible, not in rail.

---

## Reporting back

When done, summarize for the user:

- Before/after vs reference captures (which phases landed).
- Remaining gaps honestly (outliner, real vault, RAG citations).
- Files touched count; confirm no vendor dirs modified.
- Whether font banner is gone and grep gates pass.

**Do not git commit** unless the user explicitly requests it.

---

*Prompt version: 1.0 — 2026-05-17. Pair with [HANDOFF.md](./HANDOFF.md).*
