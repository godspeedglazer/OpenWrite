# OpenWrite — Opus 4.7 Execution Handoff

**Audience:** Claude Opus 4.7 xhigh (or any agent taking a stabilization pass)  
**Purpose:** Single execution brief — honest, prioritized, file-grounded. **Do not treat “shipped” commits as user-verified fixes.**  
**Date written:** 2026-05-17  
**Repo root:** `/Users/erichspringer/Downloads/OpenWrite`

---

## Mission

Make OpenWrite **usable as a daily writing app on macOS** before any new product epics:

1. **P0:** Editor body renders and scrolls; no layout fork-bomb; chat transcript scrolls top-to-bottom; launch lands on **Editor + Welcome** (not blank / wrong tab).
2. **P1:** Chat + LM Studio UX is truthful; Refine works or fails clearly; shell chrome (traffic lights, tab bar height, sheets) matches Anytype-inspired spec without copying vendor code.
3. **P2:** RAG/indexing is quiet when LM Studio is off; themes propagate everywhere object-type colors respect the active palette.
4. **P3:** Dead-code cleanup and documented tech debt only after P0–P2 are green on a **clean Debug build** on the user’s machine.

**Not in scope for this pass:** Affine BlockSuite port, Anytype Electron/TS stack, real encrypted on-disk vault, cloud sync, mobile.

---

## Current git state (how to verify)

```bash
cd /Users/erichspringer/Downloads/OpenWrite
git branch --show-current    # expect: main
git rev-parse HEAD           # record before/after your work
git log -15 --oneline
git status -sb
```

| Field | Value (at handoff authoring) |
|-------|------------------------------|
| **Branch** | `main` |
| **HEAD** | `8c228e409611c1113476e7b29f7e53a0b0d721a4` |
| **Latest commit** | `8c228e4` — Detect LM Studio connection live; support any chat model; paste images in chat |

**Recent landmark commits (read with `git show <hash>`):**

| Hash | Claim | User-reported reality |
|------|-------|------------------------|
| `8c228e4` | Live LM detection, any chat model, paste images in chat | **Verify** — persistence still seeds `gemma-4-e4b` when chat field empty |
| `5108811` | Chat connection, scroll, image paste | **Verify** — user has reported scroll still broken 50+ times |
| `6822254` | Block editor rendering lifecycle | **Verify** — empty body may persist |
| `efd890b` | Chat `ScrollView` top-to-bottom | **Verify** — may not fix user machine |
| `d24845a` | Stepper layout, token errors, editor body | **Verify** |
| `da0d314` | Editor body + sheet over shell | **Verify** sheets / lavender void |
| `dbb8f66` | Fork-bomb stop, blank launch, SwiftUI editor scroll | **Verify** RAM/CPU on Welcome 60s idle |
| `99d9da1` | Measure/layout feedback loop (23GB RAM) | **Verify** — root cause may resurface |
| `cfcff62` | Welcome layout loop, width compile | Historical |
| `aeaebc2` | Theme debounce, title bar controls | **Verify** theme lag |
| `c3035e7` | Selection context menu inline refine | Refine still glitchy for users |
| `51154c9` | Incremental vault index on edits | **Verify** reindex-on-launch behavior |

**Referenced but not on current `main` log (may be local / squashed / agent-only):**

- `cf04781c` — user cited uncommitted traffic-light placement work (3 files: `OWWindowChrome`, `OWShellTitleBar`, related). **HEAD has related changes in `8c228e4`** — still verify visually.
- `f57b3ebc` — aesthetics audit (hardcoded colors) — **no commit with this hash in repo history**; treat as checklist item below.
- `f3c8eafe` — dead-code audit summary — **no commit with this hash in repo history**; grep and remove only with proof.

---

## Non-negotiable constraints

| Rule | Detail |
|------|--------|
| **No SF Symbols in product UI** | No `Image(systemName:)`, `systemImage`, or SF-only chrome in `OpenWrite/OpenWrite/UI/**`. Grep before merge. |
| **Unicode icons only** | `OWUnicodeIcon` / `OWUnicodeIconView` — see `docs/design/OWIcons.md`. |
| **Design tokens** | Colors, spacing, typography via `DesignTokens`, `OWTypography`, `openWritePalette` environment — no drive-by hex in views. |
| **No Anytype / AFFiNE code copy** | Study gitignored `anytype-ts-develop/`, `AFFiNE-canary/` for **patterns only** (ASAL / license). |
| **Editor layout safety** | Do **not** call full `applyDocumentLayout` on every keystroke. Do **not** call `scheduleRefreshDocumentSize` from every `updateNSView` without structure/width gates. See `OWBlockEditorView` / `InlineAssistController.invalidateMeasurementCache`. |
| **Writing-first layout** | Center editor ≥ 55% width at 1200×800 with assist open (`DesignTokens.Layout.editorMinWidthFraction`). |
| **Commits** | Only when the user asks. This handoff does not authorize drive-by refactors. |
| **Build** | `cd OpenWrite && xcodebuild -scheme OpenWrite -configuration Debug build -derivedDataPath /tmp/OpenWriteDerived` |

---

## Priority 0 — App unusable (fix in order)

### P0.1 — Writing engine: empty body / blocks not rendering

**User symptom:** Welcome (and other notes) show **title, toolbar, header** but **no block body** (callout, headings, bullets missing). Reported broken across **many commits**; blocks “gone” for extended period.

**Suspected architecture:** SwiftUI `ScrollView` in `EditorView` wraps AppKit `NSHostingView` block host (`BlockEditorPasteCaptureView` in `OWBlockEditorView.swift`). Height bridge: `laidOutHeight` + `measureDocumentSize` / `publishDocumentHeight`. Empty body often means **zero height**, **blocks not synced into `editingBlocks`**, or **host not laid out** after navigation.

**Primary files:**

| File | Role |
|------|------|
| `OpenWrite/OpenWrite/UI/EditorView.swift` | `editingBlocks`, `syncFromDocument`, `editorScrollSurface`, toolbar Refine |
| `OpenWrite/OpenWrite/UI/Editor/OWBlockEditorView.swift` | `BlockEditorPasteHost`, `updateNSView` measure/apply split |
| `OpenWrite/OpenWrite/UI/Editor/InlineAssistController.swift` | `invalidateMeasurementCache` — fork-bomb history |
| `OpenWrite/OpenWrite/UI/Editor/OWPreviewBlockRow.swift` | Per-block preview/edit rows |
| `OpenWrite/OpenWrite/UI/Editor/OWBlockTextEditor.swift` | `NSTextView` per block |
| `OpenWrite/OpenWrite/Models/VaultDocument.swift` | Welcome seed `welcomeDocumentID` |
| `OpenWrite/OpenWrite/NoteDSL/NoteBlock.swift` | Block model |

**Commits that claimed fix (still verify):** `da0d314`, `d24845a`, `6822254`, `dbb8f66`, `cfcff62`, `99d9da1`.

**Acceptance criteria:**

1. Clean build → launch → **Editor** tab → **Welcome to OpenWrite**.
2. Visible body: callout, “Space” H1, bullet list (per seeded content).
3. Type in a paragraph block; text persists after switching note and back.
4. Activity Monitor: **idle 60s on Welcome**, CPU **&lt; 15%**, RAM **stable** (not climbing past ~500 MB on a typical Mac).

**Debug hooks:**

- Breakpoint `EditorView.syncFromDocument` — confirm `editingBlocks` non-empty for Welcome.
- Log `laidOutHeight` and `measureDocumentSize.height` after `onAppear`.
- If body flashes then disappears: check `onChange(of: document?.updatedAt)` clearing blocks in `EditorView`.

---

### P0.2 — Layout fork-bomb (23 GB RAM, 99% CPU)

**User symptom:** Opening Welcome (or editing) drives **runaway memory** (reported **23 GB**) and **99% CPU**; AttributeGraph / layout warnings in console.

**Root cause (documented in code):** Feedback loop between **intrinsic content size**, **`invalidateMeasurementCache`**, and **`applyDocumentLayout`** — see comment in `InlineAssistController.swift` (~line 498) and `OpenWriteThemedScrollView.swift`.

**Primary files:**

| File | Role |
|------|------|
| `OpenWrite/OpenWrite/UI/Editor/OWBlockEditorView.swift` | `invalidateMeasurementCache` on theme/preview; `scheduleLayout` coalescing |
| `OpenWrite/OpenWrite/UI/Editor/InlineAssistController.swift` | `BlockEditorPasteCaptureView.invalidateMeasurementCache` |
| `OpenWrite/OpenWrite/UI/EditorView.swift` | SwiftUI `ScrollView` instead of NSScrollView for editor body |
| `OpenWrite/OpenWrite/UI/Design/OpenWriteThemedScrollView.swift` | Chat/editor scroll bridges |

**Commits:** `99d9da1`, `dbb8f66`, `cfcff62`, `533ac6d`.

**Acceptance criteria:**

1. Open Welcome, scroll full document, type 30s — **no** sustained CPU peg.
2. RAM after 60s idle **≤ 500 MB** (order-of-magnitude; not a hard CI gate).
3. No unbounded `invalidateMeasurementCache` loop when only **typing** (content revision path should use `publishDocumentHeight`, not full structure invalidation).

**Regression guard:** Never reintroduce `layout()` async re-entry on paste host; keep `sizeThatFits` read-only (see `OWBlockEditorView.sizeThatFits` comment).

---

### P0.3 — Chat transcript scroll (cannot scroll top to bottom)

**User symptom:** User reports **50+ times** — cannot scroll the full chat history; bottom clips; stuck when not pinned. Agents claimed fix in `efd890b` / `5108811`; **user still broken**.

**Implementation:** `ChatTranscriptScrollView` in `ChatPanelView.swift` (~1587+) — SwiftUI `ScrollView`, `ScrollViewReader`, top/bottom anchors, `isPinnedToBottom` with 48pt threshold, `chatScrollToken` drives auto-scroll only when pinned.

**Primary files:**

| File | Role |
|------|------|
| `OpenWrite/OpenWrite/UI/AI/ChatPanelView.swift` | `ChatTranscriptScrollView`, `chatPinnedToBottom`, composer |
| `OpenWrite/OpenWrite/UI/Shell/AIAssistStripView.swift` | Strip width / clipping |
| `OpenWrite/OpenWrite/Design/DesignTokens.swift` | `assistStripMessageListPadding`, composer metrics |

**Acceptance criteria:**

1. Send **10+** turns until transcript exceeds viewport height.
2. **Manual scroll to top** — first message fully visible; scrollbar reaches top.
3. Scroll to bottom — last message + stepper visible.
4. Scroll up, send new message — **does not** yank viewport unless user was already pinned to bottom (`isPinnedToBottom`).
5. Resize assist strip narrow/wide — scroll range still correct.

**If still broken, try:** `NSScrollView` wrapper for transcript only; fix `safeAreaInset` composer stealing scrollable height; audit `GeometryReader` + preference key race; test macOS 14 vs 15 `ScrollView` behavior.

---

### P0.4 — Blank editor on launch / wrong center tab (Graph vs Editor)

**User symptom:** Launch shows **empty center** or **Graph** instead of **Editor** with Welcome.

**Primary files:**

| File | Role |
|------|------|
| `OpenWrite/OpenWrite/UI/ContentView.swift` | `.onAppear { workbench.showEditor() }`; `prepareVaultIndex` task |
| `OpenWrite/OpenWrite/Core/Vault/VaultStore.swift` | `bootstrapOnLaunch()` → `selectedDocumentID` Welcome |
| `OpenWrite/OpenWrite/UI/Shell/AnytypeShellView.swift` | Center tab routing, `GraphView` vs `EditorView` |
| `OpenWrite/OpenWrite/UI/Workbench/WorkbenchState.swift` | `centerTab`, `showEditor()`, `showGraph()` |

**Commits:** `dbb8f66` (blank launch).

**Acceptance criteria:**

1. Fresh launch (quit app, clean build optional): center tab **Editor**, document **Welcome** (or first doc if Welcome missing).
2. No blank white/lavender column where blocks should be (distinct from P0.1 — tab may be correct but body empty).
3. User selects Graph, quits, relaunches — product decision: **remember last tab** vs **always Editor**; document current behavior and align with `ContentView.onAppear` forcing editor.

---

## Priority 1 — Chat & AI

### P1.1 — Model caption shows `google/gemma-4-e4b · not checked` (need live LM Studio detection)

**User symptom:** Composer caption displays persisted default **gemma** and **not checked** even when LM Studio is running with a different model.

**Root causes to audit:**

| Location | Issue |
|----------|--------|
| `LMStudioConfig.defaultChatModelID` | Still `"gemma-4-e4b"` in `LMStudioConfig.swift` |
| `LMStudioConfigPersistence.decode` | Empty/`local-model` → **forces** `defaultChatModelID` (gemma) on load |
| `OpenWriteAIServices.checkConnection()` | `8c228e4` resolves from `/v1/models` — must run **before** first send and update caption |
| `ChatPanelView.composerModelCaptionText` | `"\(lmConfig.chatModelDisplay) · \(modelConnectionLabel)"` |

**Primary files:** `OpenWriteAIServices.swift`, `LMStudioConfig.swift`, `LMStudioConfigPersistence.swift`, `AISettingsView.swift`, `ChatPanelView.swift` (`.task { await checkConnection() }` on conversation panel).

**Acceptance criteria:**

1. LM Studio **off** → caption ends with **`LM Studio offline`** or **`not connected`**, not `connected`.
2. LM Studio **on**, model loaded → after ~2s caption shows **actual loaded model id** (any model, not Gemma-specific) · **`connected`**.
3. Settings chat picker lists **all** `availableModels` from server.
4. New install with empty config → first successful `listModels` sets chat model to **first server model**, not hardcoded gemma string in UI.

---

### P1.2 — Remove Gemma auto-pick bias in `checkConnection`

**User symptom:** App behaves as if Gemma is the only supported chat model.

**Code paths:**

- `OpenWriteAIServices.resolveChatModelID` — comment says “never Gemma-specific” but persistence still injects gemma default.
- `applyConfig` / `rebuildPipeline` after model change.

**Acceptance criteria:** With LM Studio serving `llama-3-8b` (example), chat uses that model without user manually clearing gemma from plist/json. Grep `gemma` — only as **example** in docs or removed from default.

---

### P1.3 — Chat stepper overlap & yellow errors

**User symptom:** Pipeline steps **overlap**; error text **yellow/garish** (off-brand).

**Commits claiming fix:** `d24845a`, `0d1933c`.

**Primary files:** `ChatPanelView.swift` (`ChatPipelineStep`, `messageRow`, error bubble styles), `DesignTokens.Color` for errors (must use semantic error tokens, not `.yellow` / system colors).

**Acceptance criteria:**

1. Connect → search → sources → respond → done: **vertical stepper** readable at minimum assist width.
2. On failure: **one** failed connect step; respond/done not left **active** alongside failed connect (`failConnectPipelineStep`).
3. Error bubbles use `DesignTokens` / palette **error** or **textSecondary** — no system yellow.

---

### P1.4 — Connection step lies (“Connected” when failed)

**User symptom:** Stepper shows **Connected** before HTTP stream works, or while LM Studio is down.

**Commits:** `cfcff62`, `5108811`, `finishConnectPipelineStep` / `failConnectPipelineStep` in `ChatPanelModel`.

**Acceptance criteria:**

1. LM Studio off → send message → connect step **fails** within **`AISafetyLimits.chatStreamTimeoutSeconds`** (30s) with diagnosis text.
2. Connect step completes only after **`markChatStreamConnected`** / first token / `.streaming` activity.
3. `OpenWriteAIServices.isLMStudioConnected` false when offline — Settings status matches composer caption.

---

### P1.5 — Refine sheet / menu glitchy; “Select text inside block”

**User symptom:** Right-click **Refine** presets and toolbar **Refine** open sheet but **fail** or feel broken; message **“Select text inside a block (drag across words)…”** even when user believes they selected text.

**Primary files:**

| File | Role |
|------|------|
| `OpenWrite/OpenWrite/UI/Editor/InlineAssistController.swift` | `scheduleSelectionCapture`, `commitPendingCapture`, `latestSnapshot` |
| `OpenWrite/OpenWrite/UI/EditorView.swift` | `requestInlineRefine`, `performToolbarInlineRefine`, `presentRefineMessage` |
| `OpenWrite/OpenWrite/UI/Editor/OWBlockTextEditor.swift` | Context menu presets |
| `docs/design/InlineAIEditing.md` | Spec |

**Known gaps:**

- Selection capture debounced (~0.4s); toolbar Refine may run before `commitPendingCapture`.
- `canRefineSelection` requires `latestSnapshot` — focus/selection across AppKit bridge fragile.
- Apply path uses string/range fallback — not full block-range guarantee.

**Acceptance criteria:**

1. Select words in paragraph → right-click **Improve** → sheet streams result (LM Studio on).
2. Toolbar **Refine** after selection → same.
3. No selection → sheet shows **actionable** message (not empty sheet / spinner forever).
4. LM Studio off → clear message pointing to Settings (see `refineLMUnavailableMessage`).
5. **Apply** replaces selected text in block without corrupting adjacent blocks.

---

### P1.6 — Chat composer icons too small; search doesn’t look like search; mystery second button

**User symptom:** 2×2 composer board icons too small; **vault search** toggle doesn’t read as “search”; user forgot **web fetch** toggle (currently `.wiki` icon).

**Primary files:**

| File | Constants |
|------|-----------|
| `DesignTokens.swift` | `composerActionSize` (36), `composerBoardIconSize` (18) |
| `ChatPanelView.swift` | `composerActionBoard`, `OWThemedToggleButton` |
| `OWThemedControls.swift` | `OWComposerIconButtonStyle` |
| `OWUnicodeIcon.swift` | `.search`, `.wiki`, `.document`, `.send` |

**Acceptance criteria:**

1. Hit targets ≥ **44pt** (Apple HIG) or documented exception with larger visual glyph (≥ 22pt).
2. Vault toggle: **magnifying glass** + tooltip “Search vault notes” + optional short label when strip wide.
3. Web toggle: distinct from search (e.g. **globe/link** unicode) + tooltip “Fetch web pages”.
4. Attach + Send visually distinct; disabled state obvious.

---

### P1.7 — Paste images in chat with preview chips above composer

**User symptom:** User wants **⌘V image paste** with **thumbnail chips** above composer (not only file importer).

**Commits:** `5108811`, `8c228e4` — `ChatComposerPasteHost`, `pendingAttachmentRow`, `importImageFromPasteboard`.

**Primary files:** `ChatPanelView.swift`, `ChatAttachmentStore.swift`.

**Acceptance criteria:**

1. Paste image in composer → chip appears in `pendingAttachmentRow` with thumbnail.
2. Send → user bubble shows attachment; model receives image path per agent config.
3. Multiple images stack horizontally; remove **×** works.

---

## Priority 1 — Chrome / layout

### P1.8 — Traffic lights misplaced; gray void where system lights were

**User symptom:** Custom **close/minimize/zoom** controls are good idea but sit **below** native traffic-light position; **gray/discolored void** left in titlebar.

**Primary files:**

| File | Role |
|------|------|
| `OWWindowChrome.swift` | `hideSystemTrafficLights`, `paintThemeFrame`, `OWSolidTitlebarAccessory`, `OWShellWindowControls` |
| `OWShellTitleBar` (same file ~475+) | Custom controls + tab strip |
| `DesignTokens.Layout` | `windowControlTopInset` (6), `shellChromeSafeAreaTop` (20), `windowControlLeadingInset` (12) |
| `AppDelegate.swift` | `OWWindowChrome.apply` on launch |

**Acceptance criteria:**

1. Custom controls align to **macOS traffic-light vertical position** (visually match system inset for titled window).
2. No **unpainted gray vibrancy** band above shell chrome — `paintThemeFrame` + accessory fill match `palette.shellChrome`.
3. Fullscreen / compact width: controls not clipped.
4. **Sheets** keep **native** traffic lights (`canApplyChrome` excludes sheets) — do not hide system buttons without replacements on sheet windows.

---

### P1.9 — Editor / Graph tabs consume ~⅕ of window height

**User symptom:** `OWShellTitleBar` + safe area too tall; wastes vertical space.

**Knobs:** `shellChromeSafeAreaTop` (20) + `shellChromeBarHeight` (36) + border — `DesignTokens.swift` ~431–439.

**Acceptance criteria:**

1. Measure titlebar band vs Apple HIG / Anytype reference screenshots in `docs/assets/`.
2. Target: tab row **≤ 28–32pt** content + minimal safe area (not ~56pt+ total chrome).
3. Editor content starts materially higher; graph canvas gains height.

---

### P1.10 — Page options ⋯ misaligned on cover/header

**User symptom:** `pageOptionsMenu` overlay misaligned on banner/cover.

**Primary file:** `OWPageHeaderEditor.swift` — `.overlay(alignment: .topTrailing)` with `editorChromePadding` / `bannerContentTopInset`.

**Acceptance criteria:** ⋯ menu aligns with cover edge and title baseline across: no cover, gradient cover, image cover; narrow window.

---

### P1.11 — Sheets (Cover, Settings) hide entire app / lavender void

**User symptom:** Opening cover picker or settings shows **full-screen lavender/void** instead of **dimmed shell** behind sheet.

**Commits:** `da0d314` — `openWriteSheetPresentationChrome()` in `OWThemedControls.swift` (`.presentationBackground`, `.presentationSizing(.fitted)` on macOS 15+).

**Primary files:** `ContentView.swift` sheets, `EditorView` refine sheet, `OWPageHeaderEditor` cover popover/sheet.

**Acceptance criteria:**

1. Sheet is **sized to content**; parent window remains visible and dimmed.
2. Background uses `DesignTokens.Color.background` for **active theme**, not hardcoded lavender.
3. Cover flow: popover vs sheet — user can complete without losing shell context.

---

### P1.12 — Theme switch spam / lag

**User symptom:** Rapid theme cycling causes **UI lag** and layout storms.

**Commits:** `aeaebc2` — debounced `ThemeManager.select`, revision-gated `OWWindowChromeConfigurator`.

**Primary files:** `ThemeManager.swift`, `OWWindowChrome.swift`, `OWNavigationRail.swift`, avoid `.id(themeManager.revision)` on root that tears down `LaunchRootView`.

**Acceptance criteria:**

1. Cycle all **13** themes in 10s — no multi-second freeze; no intro replay.
2. Editor, chat, titlebar update colors; AppKit block host receives theme refresh without full document relayout storm.

---

## Priority 2 — RAG / ingestion

### P2.1 — Embedding storm to `127.0.0.1:1234` when LM Studio off

**User symptom:** Launch or index triggers **many** failed embedding HTTP calls.

**Mitigations in code:** `LMStudioEmbeddingCircuit` (`EmbeddingService.swift`), `embeddingCircuitCooldownSeconds` (120), `openWriteEmbeddingUnreachable` notification, hash fallback `LocalHashEmbeddingService`.

**Primary files:** `OpenWriteAIServices.swift` (`prepareVaultIndex`, `reindex`), `IngestionPipeline.swift`, `ContentView.scheduleDebouncedReindex`.

**Acceptance criteria:**

1. LM Studio off → launch → **≤ 1** embedding attempt per cooldown window, then hash fallback only.
2. No log spam of concurrent `/v1/embeddings` for every chunk.
3. Settings shows clear “using local embedding fallback” once.

---

### P2.2 — Duplicate Welcome indexing (in-app + `Welcome.md`)

**User symptom:** Same Welcome content indexed twice → duplicate citation pills.

**Code:** `OpenWriteAIServices.indexEntries` skips in-app welcome when `Welcome.md` exists on disk (`welcomeDocumentID`).

**Primary files:** `OpenWriteAIServices.swift`, `VaultLocationPreferences.seedWelcomeMarkdownIfNeeded`, `VaultDocument.welcomeDocumentID`.

**Acceptance criteria:** With disk vault + Welcome.md, index contains **one** Welcome source; pills show `Welcome.md` not duplicate titles.

---

### P2.3 — Reindex on every launch

**User symptom:** Every launch rebuilds index even when unchanged.

**Code:** `prepareVaultIndex` loads disk vectors and skips `reindex` if `chunkCount > 0` and signature matches; `ContentView` also `scheduleDebouncedReindex` on appear via backlink rebuild.

**Acceptance criteria:**

1. Second launch with same vault → **no full reindex** (log or breakpoint on `reindex(documents:)`).
2. Edit note → debounced **incremental** `reindexChangedDocuments` only.
3. Settings **Rebuild index** still forces full rebuild.

---

## Priority 2 — Themes

### P2.4 — 13 themes; many surfaces still hardcoded

**User symptom:** After theme change, some panels stay wrong color (audit `f57b3ebc` — not in git).

**Process:**

1. Grep `Color(`, `NSColor(`, `.white`, `.black`, `Color.gray`, hex literals in `OpenWrite/OpenWrite/UI`.
2. Route through `openWritePalette` or `DesignTokens.Color` dynamic lookups.
3. Update `docs/design/CurrentUIAudit.md` when fixed.

**Acceptance criteria:** All 13 `ThemeID` cases: editor background, rail, chat, graph, sheets, popovers visually coherent.

---

### P2.5 — `ObjectType` colors use `NSAppearance`, not active palette

**Issue:** `DesignTokens.ObjectType.accent` uses `Color.adaptive(light:dark:)` with `NSColor(name:)` appearance callback — **not** `ThemePalette` semantic accents. Theme change may not shift object-type colors coherently.

**File:** `DesignTokens.swift` `enum ObjectType` (~107–138).

**Acceptance criteria:** Object row/icon/chip colors derive from **theme-aware palette** (or fixed per-theme table in `ThemePalette`), verified when switching Solarized ↔ Lavender Mist.

---

## Priority 3 — Dead code / tech debt

### P3.1 — Dead code audit (`f3c8eafe` referenced)

No commit `f3c8eafe` on `main`. Run fresh audit:

- Unreachable views, `NoOp*` services slated for replacement, deprecated `OWIcon` paths.
- Do **not** delete `VoiceInputService` stubs without product sign-off.

**Output:** Short list in PR description; delete only with `xcodebuild` clean.

---

### P3.2 — Affine / Anytype rewrite **not done**

**Reality:** Stability patches only — **no** BlockSuite, **no** Electron shell. Reference trees (gitignored): `AFFiNE-canary/`, `anytype-ts-develop/`, `reor-main/`, `logseq-master/`.

**Use references for:** RAG patterns (Reor), outliner ops (Logseq), workbench density (Anytype) — **clean-room SwiftUI** only.

---

## Per-area file map

### Editor

| Concern | Files |
|---------|--------|
| Document shell | `EditorView.swift` |
| Block host | `OWBlockEditorView.swift`, `OWPreviewBlockRow.swift`, `OWBlockTextEditor.swift` |
| Inline AI | `InlineAssistController.swift` |
| Page header | `OWPageHeaderEditor.swift`, `OWPageHero.swift`, `OWPageBanner.swift` |
| NDL | `NoteBlock.swift`, `NDLParser.swift` |

### Chat

| Concern | Files |
|---------|--------|
| UI + model | `ChatPanelView.swift` (`ChatPanelModel`, `ChatTranscriptScrollView`) |
| Strip shell | `AIAssistStripView.swift`, `AIAssistBottomBar.swift` |
| Agents | `AgentRegistry.swift`, `BuiltInAgents.swift` |
| Attachments | `ChatAttachmentStore.swift` |

### Shell

| Concern | Files |
|---------|--------|
| Layout | `AnytypeShellView.swift`, `WorkbenchState.swift` |
| Titlebar | `OWWindowChrome.swift` (`OWShellTitleBar`, `OWShellWindowControls`) |
| Rail | `OWNavigationRail.swift`, `OWSidebarSection.swift` |
| Root | `ContentView.swift`, `OpenWriteApp.swift`, `LaunchIntroView.swift` |

### AI / indexing

| Concern | Files |
|---------|--------|
| Orchestration | `OpenWriteAIServices.swift` |
| LM Studio | `LMStudioClient.swift`, `LMStudioConfig.swift`, `LMStudioConfigPersistence.swift` |
| RAG | `RAGService.swift`, `HybridRetrievalService.swift` |
| Embeddings | `EmbeddingService.swift`, `IngestionPipeline.swift`, `InMemoryVectorStore.swift` |
| Settings | `AISettingsView.swift`, `OpenWriteSettingsView.swift` |

### Graph

| Concern | Files |
|---------|--------|
| View | `GraphView.swift`, `GraphViewModel.swift` |
| Placeholder | `GraphPlaceholderView.swift` |

### Design system

| Concern | Files |
|---------|--------|
| Tokens | `DesignTokens.swift` |
| Typography | `OWTypography.swift` |
| Icons | `OWUnicodeIcon.swift` |
| Themes | `ThemeManager.swift`, `ThemePalette.swift`, `ThemeID.swift` |
| Controls | `OWThemedControls.swift` |

---

## What’s already committed (honest — may not work for user)

| Area | Commit(s) | Agent claim | Trust level |
|------|-----------|-------------|-------------|
| Editor SwiftUI scroll + measure split | `dbb8f66`, `6822254` | Body renders, no fork-bomb | **Low** — user reports empty body |
| Chat ScrollView transcript | `efd890b`, `5108811` | Full scroll | **Low** — user reports 50+ failures |
| Chat connect honesty | `cfcff62`, `5108811`, `0d1933c` | No false “Connected” | **Medium** — verify on LM Studio off |
| Stepper layout / token errors | `d24845a` | Fixed overlap/yellow | **Medium** — verify visually |
| Sheet presentation | `da0d314` | Dimmed shell | **Low** — lavender void reports |
| Theme debounce | `aeaebc2` | No spam | **Medium** |
| Titlebar custom controls | `aeaebc2`, `8c228e4` | Integrated strip | **Low** — alignment/void reports |
| LM live + any model | `8c228e4` | Gemma bias removed | **Medium** — persistence still defaults gemma |
| Image paste in chat | `5108811`, `8c228e4` | Chips + paste | **Medium** — verify ⌘V |
| Incremental index | `51154c9` | Debounced reindex | **Medium** |
| Graph rect nodes | `932e576` | Usable graph | **High** for graph-only |
| Inline refine menu | `c3035e7` | Context menu | **Low** — glitchy apply |

**Docs drift:** `docs/design/CurrentUIAudit.md` and `docs/design/FrontendPriorities.md` mark many P0 rows **Pass** — treat as **aspirational** until user confirms on clean build.

---

## Regression checklist (run before declaring done)

Copy this checklist into PR / session notes. **All must pass** on a **clean** Debug build (`Product → Clean Build Folder`).

### Build & launch

- [ ] `xcodebuild -scheme OpenWrite -configuration Debug build` succeeds
- [ ] App launches to **Editor** + **Welcome** (not blank center, not stuck on Graph unless intended)

### Editor (P0)

- [ ] Welcome body blocks visible and scrollable end-to-end
- [ ] Type 30s in paragraph — no CPU peg; RAM stable 60s idle
- [ ] Switch to another note and back — content preserved

### Chat (P0 + P1)

- [ ] 10+ message transcript — scroll to **top** and **bottom** reliably
- [ ] LM Studio **off** — send fails ≤30s, honest connect failure, caption **not connected**
- [ ] LM Studio **on** — caption shows **loaded model name** · **connected**
- [ ] Paste image — chip above composer; send works
- [ ] Stepper: no overlap; errors on-brand

### Refine (P1)

- [ ] Selection + right-click refine — streams result when LM Studio on
- [ ] Toolbar refine without selection — clear message
- [ ] Apply updates selection only

### Chrome (P1)

- [ ] Traffic lights aligned; no gray void in titlebar
- [ ] Tab bar height reduced vs current (~⅕ window complaint)
- [ ] Open Settings / cover — shell visible behind sheet
- [ ] Cycle 13 themes — no lag storm; colors coherent

### RAG (P2)

- [ ] LM Studio off — no embedding HTTP storm in Console
- [ ] Second launch — no full reindex if vault unchanged
- [ ] Welcome not double-indexed when `Welcome.md` on disk

### Anti-patterns

- [ ] `rg 'systemName:|systemImage' OpenWrite/OpenWrite/UI` — no matches
- [ ] No new per-keystroke `applyDocumentLayout` without guards

---

## Suggested implementation order (1–2 week plan)

### Week 1 — Unblock writing

| Day | Focus | Deliverable |
|-----|--------|-------------|
| 1 | P0.1 empty body | `editingBlocks` sync + height bridge proven with logs; Welcome shows all blocks |
| 2 | P0.2 fork-bomb | Instrument `invalidateMeasurementCache`; lock keystroke vs structure paths |
| 3 | P0.3 chat scroll | Reproduce on 14/15; fix pin/height; optional AppKit scroll fallback |
| 4 | P0.4 launch tab | `WorkbenchState` + `VaultStore` selection hardened |
| 5 | Integration | Full regression checklist; user smoke test |

### Week 2 — Trust + polish

| Day | Focus | Deliverable |
|-----|--------|-------------|
| 6 | P1.1–P1.4 LM + stepper | Truthful caption; remove gemma default bias; stepper QA |
| 7 | P1.5 refine | Selection capture + apply path |
| 8 | P1.6–P1.7 composer | Icon size/labels; paste chips polish |
| 9 | P1.8–P1.11 chrome | Traffic lights, tab height, sheets, page ⋯ |
| 10 | P1.12 + P2 themes/RAG | Theme lag; embedding storm; object colors |
| 11–12 | Buffer | Graph polish, doc audit updates, dead code triage |

---

## Out of scope for this pass

- Production `.openwrite` encrypted vault on disk + Keychain (E-01)
- Full NDL outliner (indent/outdent, slash, drag reorder) (E-02)
- Citation-quality RAG product story (E-03) beyond basic pills
- FSEvents persistent vector store (E-04/05)
- Cloud sync, plugins, iOS, in-app browser
- Porting AFFiNE BlockSuite or Anytype TS stack
- Replacing `AGENTS.md` Aegis manifest rules (different product in workspace parent — OpenWrite is independent app under `OpenWrite/`)

---

## Related documents

| Doc | Use |
|-----|-----|
| [docs/HANDOFF.md](docs/HANDOFF.md) | Short index + anchors into this file |
| [AGENT_PROMPT_UI_REFACTOR.md](AGENT_PROMPT_UI_REFACTOR.md) | Phase 0 UI agent entry (points here) |
| [docs/design/UIRefactorBrief.md](docs/design/UIRefactorBrief.md) | Visual spec |
| [docs/design/FrontendPriorities.md](docs/design/FrontendPriorities.md) | P0 checklist (verify against reality) |
| [docs/design/CurrentUIAudit.md](docs/design/CurrentUIAudit.md) | Brutal audit table |
| [BUGFIXES.md](BUGFIXES.md) | 2026-05-17 sweep log |
| [docs/FeatureParityMatrix.md](docs/FeatureParityMatrix.md) | 357-row maturity |
| [docs/design/InlineAIEditing.md](docs/design/InlineAIEditing.md) | Refine spec |

---

## Appendix A — User-reported issue consolidation (deduped)

| ID | Priority | Summary | Section |
|----|----------|---------|---------|
| U1 | P0 | Empty editor body / blocks not rendering | P0.1 |
| U2 | P0 | 23GB RAM / 99% CPU layout loop | P0.2 |
| U3 | P0 | Chat cannot scroll full transcript | P0.3 |
| U4 | P0 | Blank launch / wrong tab | P0.4 |
| U5 | P1 | Gemma caption + not checked | P1.1–P1.2 |
| U6 | P1 | Stepper overlap / yellow errors | P1.3 |
| U7 | P1 | False “Connected” | P1.4 |
| U8 | P1 | Refine broken / select text message | P1.5 |
| U9 | P1 | Composer icons / search / web button | P1.6 |
| U10 | P1 | Paste images with chips | P1.7 |
| U11 | P1 | Traffic lights + gray void | P1.8 |
| U12 | P1 | Tab bar too tall | P1.9 |
| U13 | P1 | Page ⋯ misaligned | P1.10 |
| U14 | P1 | Sheets hide app / lavender void | P1.11 |
| U15 | P1 | Theme switch lag | P1.12 |
| U16 | P2 | Embedding storm | P2.1 |
| U17 | P2 | Duplicate Welcome index | P2.2 |
| U18 | P2 | Reindex every launch | P2.3 |
| U19 | P2 | Hardcoded theme surfaces | P2.4 |
| U20 | P2 | ObjectType NSAppearance | P2.5 |
| U21 | P3 | Dead code audit | P3.1 |
| U22 | P3 | No Affine/Anytype port | P3.2 |

---

## Appendix B — Key `DesignTokens.Layout` chrome metrics (tuning targets)

```
shellChromeSafeAreaTop     = 20
shellChromeBarHeight       = 36   ← reduce for P1.9
windowControlTopInset      = 6
windowControlSize          = 14
windowControlLeadingInset  = 12
composerActionSize         = 36   ← increase for P1.6
composerBoardIconSize      = 18   ← increase for P1.6
```

---

## Appendix C — LM Studio quick test

```bash
# Server up (example)
curl -s http://127.0.0.1:1234/v1/models | head

# Server down — app must not embed-storm
# Watch Console for repeated embeddings URLs
```

Settings → AI: base URL `http://127.0.0.1:1234`, pick chat + embedding models explicitly.

---

*End of Opus 4.7 execution handoff. Update HEAD hash and trust table when `main` advances.*
