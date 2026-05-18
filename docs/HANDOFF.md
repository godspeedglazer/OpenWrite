# OpenWrite — Opus 4.7 xhigh Execution Handoff

**Audience:** Claude Opus 4.7 xhigh (or any agent taking a full stabilization pass)  
**Repo:** `/Users/erichspringer/Downloads/OpenWrite`  
**Date:** 2026-05-17  
**App code baseline (pre-handoff):** `8c228e409611c1113476e7b29f7e53a0b0d721a4` (`8c228e4`)  
**Handoff doc commit:** `8ba07f7`

**Rule:** Do **not** treat “shipped” commits as user-verified fixes. The user has screenshots and repeated reports that P0 items remain broken after many agent passes. Your job is to **reproduce on a clean Debug build**, fix root causes, and pass §G acceptance tests on the user’s machine.

**Pointer:** Short index at [../HANDOFF.md](../HANDOFF.md).

---

## A. Product intent

**OpenWrite** is a **local-first** macOS notes app in the spirit of **Anytype** (object/workbench shell) and **Reor** (vault-grounded RAG chat), implemented as **native SwiftUI + selective AppKit bridges** — not Electron, not AFFiNE BlockSuite.

| Pillar | Intent |
|--------|--------|
| **Writing** | Block-based editor (NDL / `NoteBlock`), Welcome seed, page header (cover, icon, title), outliner-style blocks without porting Logseq/AFFiNE code |
| **Knowledge** | Vault on disk, markdown catalog, hybrid retrieval, citation pills in chat |
| **AI** | OpenAI-compatible local server (LM Studio default `127.0.0.1:1234`), streaming chat, optional web fetch, inline “Refine” on selection |
| **Aesthetic** | Keep the **current Anytype-inspired shell** — rail, center card, bottom AI strip, Unicode icons (`OWUnicodeIcon`), `DesignTokens` / `ThemePalette`. **Do not** redesign the product; **fix correctness, layout, and honesty of status** |

**Out of scope for this pass:** Affine/Anytype code copy, cloud sync, mobile, in-app browser, production encrypted vault, full outliner (slash, drag-reorder), Qubes-style hardening.

**Reference trees (patterns only, gitignored or sibling):** `anytype-ts-develop/`, `reor-main/`, `AFFiNE-canary/`, `logseq-master/` — study density and RAG UX; implement clean-room Swift.

---

## B. P0 blockers (user-verified screenshots)

Fix in order. Each item blocks daily use.

### B1. Writing engine broken

**Symptom:** Welcome (and other notes) show **title, toolbar, page header** but **body empty** or a **thin strip**; user cannot write. Persists across commits `dbb8f66`, `da0d314`, `99d9da1`, `cfcff62`, `6822254`, `d24845a`.

**Likely causes:**

- `EditorView.editingBlocks` empty after `syncFromDocument` race
- AppKit `BlockEditorPasteCaptureView` reports **zero height** (`laidOutHeight` / `measureDocumentSize`)
- `onChange(of: document?.updatedAt)` or navigation clears blocks after flash
- SwiftUI `ScrollView` + `NSHostingView` height bridge not publishing on first layout

**Primary files:**

| File | Role |
|------|------|
| `OpenWrite/OpenWrite/UI/EditorView.swift` | `editingBlocks`, `editorScrollSurface`, toolbar Refine |
| `OpenWrite/OpenWrite/UI/Editor/OWBlockEditorView.swift` | `BlockEditorPasteHost`, `updateNSView` measure/apply gates |
| `OpenWrite/OpenWrite/UI/Editor/InlineAssistController.swift` | `applyDocumentLayout`, `invalidateMeasurementCache` |
| `OpenWrite/OpenWrite/UI/Editor/OWBlockTextEditor.swift` | Per-block `NSTextView` |
| `OpenWrite/OpenWrite/UI/Design/OWPreviewBlockRow.swift` | Block row chrome |
| `OpenWrite/OpenWrite/Models/VaultDocument.swift` | Welcome seed |
| `OpenWrite/OpenWrite/NoteDSL/NoteBlock.swift` | Block model |

**Done when:** Welcome shows callout + H1 “Space” + bullets; user types in a paragraph; content survives note switch; idle 60s CPU &lt; ~15%, RAM stable (not climbing toward GB).

---

### B2. Layout fork-bomb (RAM / CPU)

**Symptom:** Opening Welcome or typing drives **runaway RAM** (user reported **23 GB**) and **~99% CPU**; AttributeGraph / layout console spam.

**Root cause (documented in-tree):** Feedback between `sizeThatFits` measure, `invalidateMeasurementCache`, and `applyDocumentLayout` / `layoutSubtreeIfNeeded`. See comments in `InlineAssistController.swift` and `OpenWriteThemedScrollView.swift`.

**Commits that claimed fix:** `99d9da1`, `dbb8f66`, `cfcff62`.

**Done when:** Type 30s + scroll full doc + idle 60s without pegged CPU or climbing memory. Keystrokes must use **content-revision height publish**, not full structure invalidation every character.

---

### B3. Chat scroll broken

**Symptom:** User reports **many times** — cannot scroll transcript **top to bottom**; bottom clips; stuck when not pinned. Commits `efd890b`, `5108811` claim SwiftUI `ScrollView` fix; **user still broken**.

**Implementation:** `ChatTranscriptScrollView` in `ChatPanelView.swift` (~line 1587+) — `ScrollViewReader`, `chatScrollToken`, `isPinnedToBottom` (48pt threshold), `safeAreaInset` composer.

**Also check:** `AIAssistStripView.swift` width clipping; composer inset stealing scrollable height; macOS 14 vs 15 `ScrollView` behavior.

**Done when:** 10+ turns; manual scroll to **first** and **last** message; scroll up + new message does **not** yank unless pinned.

---

### B4. Traffic lights wrong place + gray void

**Symptom:** Custom close/minimize/zoom sit **below** standard traffic-light position; **gray/discolored void** above where system lights were. User wants controls in **standard traffic-light position** with **no void**.

**Primary files:** `OpenWrite/OpenWrite/UI/Shell/OWWindowChrome.swift` (`hideSystemTrafficLights`, `paintThemeFrame`, `OWSolidTitlebarAccessory`, `OWShellWindowControls`, `OWShellTitleBar`), `DesignTokens.Layout` (`windowControlTopInset`, `shellChromeSafeAreaTop`, `windowControlLeadingInset`), `AppDelegate.swift`.

**Done when:** Custom controls align with macOS titled-window inset; titlebar fill matches `palette.shellChrome`; no unpainted vibrancy band. Sheets must keep native lights (`canApplyChrome` excludes sheet windows).

---

### B5. Top chrome too tall

**Symptom:** Editor/Graph segment consumes ~**⅕ of window height** (`OWShellTitleBar` + safe area).

**Knobs:** `shellChromeSafeAreaTop` (20), `shellChromeBarHeight` (36) in `DesignTokens.swift`.

**Done when:** Tab row ~28–32pt content + minimal safe area; editor canvas starts materially higher.

---

### B6. Refine flow broken

**Symptom:** “+ Refine” / Improve opens **glitchy sheet**; error **“Select text inside a block (drag across words)…”** when user believes they selected; context-menu refine same path.

**Primary files:** `InlineAssistController.swift` (`scheduleSelectionCapture`, `commitPendingCapture`, `latestSnapshot`), `EditorView.swift` (`requestInlineRefine`, `performToolbarInlineRefine`), `OWBlockTextEditor.swift` context menu, `docs/design/InlineAIEditing.md`.

**Known gaps:** ~0.4s debounced selection capture; toolbar Refine may run before commit; apply uses string/range fallback.

**Done when:** Selection + right-click Improve streams (LM on); toolbar Refine matches; no selection → clear message; Apply replaces selection only.

---

### B7. LM Studio status wrong

**Symptom:** Composer shows `google/gemma-4-e4b · not checked` / `not connected` without reflecting live server; user wants **any configured model**, not Gemma-only behavior.

**See §E and “Connection logic” appendix below.**

**Done when:** LM off → offline/not connected after probe; LM on → real model id · connected within ~2s of opening chat; Settings lists `availableModels` from GET `/v1/models`.

---

### B8. Chat composer icons

**Symptom:** 2×2 board icons **too small**; vault toggle doesn’t read as **search**; user forgot **web fetch** button meaning.

**Files:** `ChatPanelView.swift` (`composerActionBoard`), `DesignTokens.Layout` (`composerActionSize` 36, `composerBoardIconSize` 18), `OWUnicodeIcon.swift`, `OWThemedControls.swift`.

**Done when:** Hit targets ≥44pt or larger glyphs (≥22pt); search = magnifying glass + tooltip; web = distinct globe/link + tooltip; attach/send visually distinct.

---

## C. P1 issues

| ID | Issue | Files / notes | Verify commits |
|----|-------|---------------|----------------|
| C1 | Sheets (Cover, Settings) **hide entire app** vs dimmed shell | `OWThemedControls.openWriteSheetPresentationChrome`, `ContentView` sheets, `EditorView` refine sheet | `da0d314` |
| C2 | Chat stepper **overlap** / **yellow** errors | `OWChatStatusStepper.swift`, `ChatPanelView` pipeline steps | `d24845a`, `0d1933c` |
| C3 | Theme switch **spam lag** | `ThemeManager.select` debounce, `OWWindowChromeConfigurator` revision gate | `aeaebc2` |
| C4 | Page header **three-dot** misaligned | `OWPageHeaderEditor.swift` overlay insets | — |
| C5 | **Image paste in chat** (⌘V chips above composer) | `ChatComposerPasteHost`, `ChatAttachmentStore`, `importImageFromPasteboard` | `5108811`, `8c228e4` |
| C6 | **Ingestion footer** + CPU/memory history in rail | `OWNavigationRail.ingestionRailFooter`, `IngestionHealthMonitor` | fork-bomb fixes don’t fix writer |
| C7 | **REMImportAdapter** — dead-code audit said “missing” | **File exists:** `OpenWrite/Core/PastWrites/REMImportAdapter.swift` (stub); wired in `PastWritesService.swift` + `project.pbxproj`. v1 = no SQLite parser | — |
| C8 | **13 themes in code vs stale “9” in older docs** | `ThemeID` has **13** cases; `docs/design/Themes.md` says thirteen. Grep repo for “9 theme” and fix stale audit rows | `ThemeID.swift` |
| C9 | False pipeline **“Connected”** before HTTP works | `markChatStreamConnected`, `finishConnectPipelineStep` / `failConnectPipelineStep` in `ChatPanelModel` | `cfcff62`, `5108811` |
| C10 | Launch **blank center** or wrong tab (Graph vs Editor) | `ContentView.onAppear`, `VaultStore.bootstrapOnLaunch`, `WorkbenchState` | `dbb8f66` |
| C11 | Embedding **HTTP storm** when LM Studio off | `LMStudioEmbeddingCircuit`, `prepareVaultIndex`, `ContentView.scheduleDebouncedReindex` | — |
| C12 | Duplicate Welcome index (in-app + `Welcome.md`) | `OpenWriteAIServices.indexEntries` skip logic | — |
| C13 | Reindex on every launch | `prepareVaultIndex` signature skip | — |
| C14 | Hardcoded colors after theme change | Grep `Color(`, hex, `.gray` in `OpenWrite/UI` | audit refs `f57b3ebc` not in git |
| C15 | `ObjectType` colors use `NSAppearance`, not `ThemePalette` | `DesignTokens.ObjectType` | — |

---

## D. Git archaeology

Run before you start; update this table when `main` advances.

```bash
cd /Users/erichspringer/Downloads/OpenWrite
git log -15 --oneline
git rev-parse HEAD
```

### Last 15 commits (at handoff authoring)

| Hash | One-line claim | User-reported reality |
|------|----------------|----------------------|
| `8c228e4` | Live LM detection; any chat model; paste images in chat | **Verify** — persistence still seeds gemma when chat empty (`LMStudioConfigPersistence.decode`) |
| `5108811` | Chat connection, scroll, image paste | **Verify** — scroll still broken per user |
| `6822254` | Block editor rendering lifecycle | **Verify** — empty body may persist |
| `8de203d` | Refresh handoff/theme docs | Docs only |
| `0d1933c` | Connect-fail pipeline step semantics after scroll merge | **Verify** stepper on LM off |
| `aeaebc2` | Theme debounce; shell title bar controls | **Verify** lag + traffic-light void |
| `efd890b` | Chat ScrollView full transcript | **Low trust** — user still broken |
| `d24845a` | Stepper layout, token errors, editor body | **Verify** overlap/yellow |
| `da0d314` | Editor body + sheet over shell | **Verify** lavender void |
| `dbb8f66` | Fork-bomb stop, blank launch, SwiftUI editor scroll | **Verify** RAM 60s idle |
| `99d9da1` | Measure/layout feedback loop (23GB) | **Verify** — may resurface |
| `51154c9` | Incremental vault index on edits | **Verify** reindex-on-launch |
| `706218e` | Welcome stability, chat connect timeout | Historical |
| `c3035e7` | Selection context menu inline refine | Refine still glitchy |
| `cfcff62` | Welcome layout loop, width compile | Historical |

**Hashes user cited but not on this log:** `cf04781c` (traffic lights, possibly uncommitted), `f57b3ebc` / `f3c8eafe` (audits) — **not in `git log`**. Treat as checklist, not commits.

---

## E. Architecture map (files)

### Editor

| Concern | Path |
|---------|------|
| Document shell | `OpenWrite/OpenWrite/UI/EditorView.swift` |
| Block host | `OpenWrite/OpenWrite/UI/Editor/OWBlockEditorView.swift` |
| Inline AI | `OpenWrite/OpenWrite/UI/Editor/InlineAssistController.swift` |
| Text views | `OpenWrite/OpenWrite/UI/Editor/OWBlockTextEditor.swift` |
| Preview rows | `OpenWrite/OpenWrite/UI/Design/OWPreviewBlockRow.swift` |
| Page header | `OpenWrite/OpenWrite/UI/Design/OWPageHeaderEditor.swift` |

### Chat

| Concern | Path |
|---------|------|
| Panel + model | `OpenWrite/OpenWrite/UI/AI/ChatPanelView.swift` |
| Stepper | `OpenWrite/OpenWrite/UI/AI/OWChatStatusStepper.swift` |
| Source pills | `OpenWrite/OpenWrite/UI/AI/RAGSourcePillsView.swift` |
| Strip shell | `OpenWrite/OpenWrite/UI/Shell/AIAssistStripView.swift` |

### AI / LM Studio

| Concern | Path |
|---------|------|
| Orchestration | `OpenWrite/OpenWrite/AI/OpenWriteAIServices.swift` |
| HTTP client | `OpenWrite/OpenWrite/AI/LMStudioClient.swift` |
| Config | `OpenWrite/OpenWrite/AI/LMStudioConfig.swift` |
| Persistence | `OpenWrite/OpenWrite/AI/LMStudioConfigPersistence.swift` |
| Settings UI | `OpenWrite/OpenWrite/UI/Settings/AISettingsView.swift` |

### Chrome / shell

| Concern | Path |
|---------|------|
| Shell layout | `OpenWrite/OpenWrite/UI/Shell/AnytypeShellView.swift` |
| Titlebar / traffic lights | `OpenWrite/OpenWrite/UI/Shell/OWWindowChrome.swift` |
| Rail | `OpenWrite/OpenWrite/UI/Shell/OWNavigationRail.swift` |
| Root | `OpenWrite/OpenWrite/UI/ContentView.swift` |
| Tokens | `OpenWrite/OpenWrite/Design/DesignTokens.swift` |
| Themes | `OpenWrite/OpenWrite/Core/Theme/ThemeManager.swift`, `ThemeID.swift`, `ThemePalette.swift` |
| Themed scroll bridge | `OpenWrite/OpenWrite/UI/Design/OpenWriteThemedScrollView.swift` |

### Reference repos (patterns only)

`AFFiNE-canary/`, `anytype-ts-develop/`, `reor-main/` — do not copy code.

---

## E2. OpenWriteAIServices — connection logic (read first)

File: `OpenWrite/OpenWrite/AI/OpenWriteAIServices.swift` (user had this open in IDE).

### State machine

`LMConnectionState`: `notChecked` → `checking` / `connecting` → `connected` | `noModelLoaded` | `offline`.

- **Initial:** `lmConnectionState = .notChecked`, `lmStatus = "Not checked"`.
- **Caption in chat:** `composerModelCaptionText` = `lmConfig.chatModelDisplay` + ` · ` + `modelConnectionLabel` (from `lmConnectionState` / `activityState`).

### When probe runs

| Trigger | Behavior |
|---------|----------|
| `ChatPanelView.conversationPanel` `.task` | `await aiServices.checkConnection()` on panel appear |
| Settings “Check connection” | `AISettingsView` button |
| `EditorView` refine path | If `notChecked` or `checking`, awaits `checkConnection()` before refine |
| After chat failure | `diagnoseChatFailure` → second `listModels()` |

### `checkConnection()` (lines ~237–266)

1. Sets `checking`, activity `connecting`, status `"Checking…"`.
2. `lmClient.listModels()` → fills `availableModels`.
3. `resolveChatModelID(current:available:)` — if saved id empty/`local-model` or not in list, **writes first server model** to `lmConfig` and `rebuildPipeline()`.
4. Empty models → `noModelLoaded`; else `connected` + idle activity.
5. Catch → `offline`, `setActivity(.error(...))`.

### Gemma bias (still present)

| Location | Issue |
|----------|--------|
| `LMStudioConfig.defaultChatModelID` | `"gemma-4-e4b"` |
| `LMStudioConfigPersistence.decode` | Empty/`local-model` → **forces** `defaultChatModelID` on load |
| UI before probe | Shows **gemma display string · not checked** even if server has other models |

`resolveChatModelID` comment says “never Gemma-specific” but **persistence injects gemma** before first successful probe.

### Optimistic / lying paths (audit)

| API | Risk |
|-----|------|
| `markChatStreamConnected()` | Sets `connected` without HTTP — called in `ChatPanelView` after stream path (~355, ~707) |
| `setActivity(.streaming)` | `modelConnectionLabel` returns **“connected”** while streaming even if probe never ran |
| `markChatStreamFailed()` | Sets `offline` |

**Fix direction:** Probe on app launch or first chat open; don’t show `connected` until `listModels()` succeeds or first token arrives; separate **configured model id** from **connection state** in caption; remove gemma as persisted default (use empty + first server model only after probe).

### Indexing (related)

- `prepareVaultIndex`, `reindex`, `reindexChangedDocuments` — embedding circuit when LM off.
- `indexEntries` skips in-app Welcome when `Welcome.md` on disk.

---

## F. Opus execution plan (phased)

Execute strictly in order; do not start chrome polish until **Phase 1** passes §G editor checks.

### Phase 1 — Restore writer (P0 B1–B2)

1. Reproduce Welcome empty body on clean build; log `editingBlocks.count`, `laidOutHeight`, `measureDocumentSize`.
2. Fix sync + height bridge; guard keystroke vs structure invalidation.
3. Activity Monitor: 60s idle on Welcome.

### Phase 2 — Chat scroll + connection + icons (P0 B3, B7–B8; P1 C2, C5, C9)

1. Fix `ChatTranscriptScrollView` height/pin; fallback to AppKit scroll if needed.
2. Truthful LM caption: launch/task probe, remove gemma default bias, fix `markChatStreamConnected` semantics.
3. Composer icon sizes, labels, tooltips.

### Phase 3 — Titlebar + top layout (P0 B4–B5)

1. Traffic lights in standard position; paint void; tune `DesignTokens.Layout` insets.
2. Compress `OWShellTitleBar` / safe area.

### Phase 4 — Refine UX (P0 B6)

1. Selection capture before toolbar Refine; sheet vs popover stability.
2. Apply path tied to block range.

### Phase 5 — Image paste, docs sync, P1/P2 cleanup

1. Verify ⌘V chips + send path.
2. Sheets dim shell; ingestion footer; theme/object color grep; update `docs/design/CurrentUIAudit.md` only with **verified** passes.
3. Sync theme count docs (13 everywhere).

---

## G. Acceptance tests (manual QA)

Copy into PR notes. **Clean Build Folder** before run.

### Build & launch

- [ ] `xcodebuild -scheme OpenWrite -configuration Debug build` succeeds
- [ ] Launch → **Editor** + **Welcome** (not blank Graph-only)

### Phase 1 — Editor

- [ ] Welcome body: callout, headings, bullets visible
- [ ] Scroll entire document
- [ ] Type 30s; switch note and back; text persists
- [ ] Idle 60s: CPU not pegged; RAM stable (not GB climb)

### Phase 2 — Chat

- [ ] 10+ messages; scroll to **top** and **bottom**
- [ ] LM Studio **off**: send fails ≤30s; caption **not connected** / offline
- [ ] LM Studio **on**: caption shows **loaded model** · **connected** within ~2s of opening chat
- [ ] Stepper: no overlap; errors use semantic tokens (not yellow)
- [ ] Paste image → chip above composer; send shows attachment

### Phase 3 — Chrome

- [ ] Traffic lights aligned; no gray void
- [ ] Tab bar no longer ~⅕ window height
- [ ] Settings/Cover sheet: shell visible, dimmed

### Phase 4 — Refine

- [ ] Selection + context Improve → streams (LM on)
- [ ] Toolbar Refine without selection → clear message
- [ ] Apply replaces selection only

### Phase 5 — Themes & RAG

- [ ] Cycle all **13** themes in 10s — no multi-second freeze
- [ ] LM off — no embedding request storm in Console
- [ ] Second launch — no full reindex if vault unchanged

### Anti-pattern grep

- [ ] `rg 'systemName:|systemImage' OpenWrite/OpenWrite/UI` — zero matches
- [ ] No per-keystroke unguarded `applyDocumentLayout`

---

## H. Anti-patterns to avoid

| Anti-pattern | Why | Where it burned us |
|--------------|-----|-------------------|
| `layoutSubtreeIfNeeded` inside `sizeThatFits` / measure | Layout feedback loop | `OpenWriteThemedScrollView`, editor host |
| `ContentView.id(themeManager.revision)` full tree rebuild | Theme lag, state loss | Removed in `aeaebc2` — **do not reintroduce** |
| `applyDocumentLayout` from `layout()` async loop | Re-entrant layout | `OWBlockEditorView` |
| `markChatStreamConnected()` before HTTP success | Lying stepper/caption | `ChatPanelView` |
| Hardcoded Gemma in `checkConnection` / persistence default | Wrong model · not checked UX | `LMStudioConfig`, `LMStudioConfigPersistence` |
| `scheduleRefreshDocumentSize` on every `updateNSView` | Fork-bomb | `OWBlockEditorView` |
| `OWWindowChrome.apply` on every `updateNSView` without revision gate | Theme spam | `OWWindowChromeConfigurator` |
| SF Symbols in product UI | Project rule | grep before merge |
| Copying Anytype/AFFiNE code | License / scope | reference only |

**Build:**

```bash
cd OpenWrite && xcodebuild -scheme OpenWrite -configuration Debug build -derivedDataPath /tmp/OpenWriteDerived
```

---

## I. Parallel agent status

Session parent: [Opus handoff chat](09ef84bb-5b2c-4376-9d25-4a4e0f697013). **Do not revert** recent chat/editor work without reading `git show` on these areas.

| Agent / ID | Focus | Status at `8c228e4` |
|------------|-------|---------------------|
| `0166d344` | (parent-delegated; scope unclear in transcript) | Assume **superseded** by later commits — grep before revert |
| `cf04781c` | Traffic lights — **3 files** cited uncommitted (`OWWindowChrome`, `OWShellTitleBar`, …) | May be **partially merged** in `aeaebc2` / `8c228e4` — **user still reports void/misplacement** |
| `a8964195` | (referenced in parent) | Verify via `git log --all --grep` / transcript |
| `a99fae37` | (referenced in parent) | Verify via transcript |
| `3d7dd9f0` | Image paste in chat | Likely **landed** in `5108811` / `8c228e4` — **verify ⌘V** |
| `e590848a` | Theme lag + traffic lights; coordinated with `74a91a4f`, `fad173eb`, `d1b9ced4` | Work included **ThemeManager** debounce, **OWWindowChromeConfigurator** revision gate, **ContentView** `.id(revision)` removal, chat pipeline tweak; merge context **`0d1933c`** |
| `74a91a4f` | Chat scroll | Landed `efd890b` lineage — **user says still broken** |
| `fad173eb` | Chat stepper / editor body | Landed `d24845a` |
| `d1b9ced4` | (coordinated with e590848a) | See parent transcript |
| `28ec115e` / `1826e077` | Prior HANDOFF writers | Superseded by **this** doc |

**Coordination rule:** If you touch `ChatPanelView.swift`, `OWWindowChrome.swift`, `ThemeManager.swift`, `EditorView.swift`, or `OWBlockEditorView.swift`, read `git diff HEAD~5` on that file first.

---

## Detailed P0/P1 implementation notes

### P0.1 empty body — debug hooks

- Breakpoint `EditorView.syncFromDocument` — `editingBlocks` non-empty for Welcome.
- Log `laidOutHeight` after `onAppear`.
- If flash then empty: `onChange(of: document?.updatedAt)`.

### P0.3 chat scroll — if still broken

- Inspect `safeAreaInset(edge: .bottom) { composer }` reducing scroll content height.
- Try `NSScrollView` wrapper for transcript only.
- Test `chatPinnedToBottom` threshold (48pt).

### P1.8 traffic lights — tuning targets

```
shellChromeSafeAreaTop     = 20   ← reduce for B5
shellChromeBarHeight       = 36   ← reduce for B5
windowControlTopInset      = 6
windowControlSize          = 14
windowControlLeadingInset  = 12
composerActionSize         = 36   ← increase for B8
composerBoardIconSize      = 18   ← increase for B8
```

### LM Studio quick test

```bash
curl -s http://127.0.0.1:1234/v1/models | head
# Server down: Console must not show embedding request storm
```

---

## What’s already committed (honest trust table)

| Area | Commit(s) | Trust |
|------|-----------|-------|
| Editor SwiftUI scroll + measure split | `dbb8f66`, `6822254` | **Low** — empty body |
| Chat ScrollView | `efd890b`, `5108811` | **Low** — user 50+ failures |
| LM live + any model | `8c228e4` | **Medium** — gemma persistence remains |
| Stepper / token errors | `d24845a`, `0d1933c` | **Medium** |
| Sheet presentation | `da0d314` | **Low** — lavender void |
| Theme debounce | `aeaebc2` | **Medium** |
| Image paste | `8c228e4` | **Medium** |
| Inline refine menu | `c3035e7` | **Low** |

**Docs drift:** `docs/design/CurrentUIAudit.md` and `docs/design/FrontendPriorities.md` may mark P0 **Pass** — treat as **aspirational** until §G passes on user machine.

---

## Related documents

| Doc | Use |
|-----|-----|
| [design/UIRefactorBrief.md](./design/UIRefactorBrief.md) | Visual spec |
| [design/FrontendPriorities.md](./design/FrontendPriorities.md) | P0 checklist (verify) |
| [design/CurrentUIAudit.md](./design/CurrentUIAudit.md) | Brutal audit |
| [design/InlineAIEditing.md](./design/InlineAIEditing.md) | Refine spec |
| [design/Themes.md](./design/Themes.md) | 13 theme catalog |
| [../AGENT_PROMPT_UI_REFACTOR.md](../AGENT_PROMPT_UI_REFACTOR.md) | Phase 0 agent entry |
| [../BUGFIXES.md](../BUGFIXES.md) | 2026-05-17 sweep |

---

## User issue index (deduped)

| ID | § | Summary |
|----|---|---------|
| U1 | B1 | Empty editor body |
| U2 | B2 | RAM/CPU fork-bomb |
| U3 | B3 | Chat scroll |
| U4 | B4 | Traffic lights + void |
| U5 | B5 | Tab bar too tall |
| U6 | B6 | Refine broken |
| U7 | B7 | LM status / gemma |
| U8 | B8 | Composer icons |
| U9 | C1 | Sheets hide app |
| U10 | C2 | Stepper overlap |
| U11 | C3 | Theme lag |
| U12 | C4 | Page ⋯ misaligned |
| U13 | C5 | Image paste |
| U14 | C6 | Ingestion footer |
| U15 | C8 | Theme doc drift |
| U16 | C11–C13 | RAG / reindex |
| U17 | C14–C15 | Hardcoded colors |

---

*End of Opus 4.7 xhigh handoff. Update HEAD in [../HANDOFF.md](../HANDOFF.md) when `main` advances.*
