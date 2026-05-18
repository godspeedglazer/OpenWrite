# OpenWrite bug fixes (2026-05-17)

Brief log from the Debug build / UI edge-case sweep.

## Build

- `xcodebuild -scheme OpenWrite -configuration Debug` — **BUILD SUCCEEDED** (clean + incremental).
- `OWBlockEditorView`: `ForEach($blocks)` binding — use `block.kind` (not `wrappedValue`) so the block editor compiles.

## Theme switching

- Removed `.id(themeManager.selectedTheme)` on the main window and settings roots (was tearing down `LaunchRootView` / workbench state and replaying the intro).
- Added `openWriteThemeAppearance()` so palette, tint, and `preferredColorScheme` refresh via `@Observable` without resetting view identity.
- `AnytypeShellView` reads `openWritePalette` from the environment for background updates.

## Launch intro

- Replaced `DispatchQueue.main.asyncAfter` with a cancellable `Task` so teardown does not call `onFinished` after the overlay is gone.
- Intro observes `themeManager.selectedTheme` so colors track mid-sequence theme cycles.

## Vault selection

- `VaultStore.reconcileSelections()` clears stale document/database IDs after snapshot import, delete, or empty vault.
- `deleteDatabase` calls `reconcileSelections()` instead of ad hoc ID repair.

## Navigation / workbench

- `AnytypeShellView` returns to the editor when the active database tab’s database is deleted.
- `OWNavigationRail` observes theme changes for rail footer refresh.

## Database table

- Empty schema (zero fields) shows a dedicated empty state instead of a blank table.
- Dismisses the entry editor sheet if the row was deleted elsewhere.
- Preview no longer force-unwraps `databases[0]`.
- Code cells use `DesignTokens.Typography.code` / `codeSmall` instead of raw `.system` fonts.

## Graph

- “No links yet” is a non-blocking overlay when notes exist but edges do not (was unreachable when `nodes` was non-empty).
- Resets pan/zoom when the vault document count changes.
- Replaced oversized circle nodes with **rounded-rect cards** (~120×56pt, icon + title) using `DesignTokens.Color.graphNode` / `graphNodeFocused`.
- **Force-directed lite** refinement after circle seed: repulsion, edge attraction, center gravity; adaptive ring radius from card size + min spacing.
- Edges draw between card borders with optional arrowheads at targets; all vault notes appear on the graph (removed >12-doc linked-only filter).
- Floating bar: note count + isolated count from per-node link degree; node tap still opens editor via `AnytypeShellView`.

## Typography / anti-patterns

- **Source Serif 4:** macOS ignores `UIAppFonts` alone — added `ATSApplicationFontsPath` = `Fonts`, folder-reference copy into `Resources/Fonts/`, and `CTFontManagerRegisterFontsForURL` in `OWTypography.verifyBundledFontsAtLaunch()` (PostScript names already matched TTFs).
- Grep: no `Image(systemName:)`, `systemImage`, or bare `Font.body` in product Swift (code blocks use `OWTypography.code*`).
- `RelatedNotesView` and `PropertyInspectorView` aligned to design tokens.

## Not changed

- `VoiceInputService` TODO stubs (no crash paths).
- No git commit per request.

---

# OpenWrite bug fixes (2026-05-17, evening sweep)

Targeted from the HANDOFF.md complaints: gray titlebar void, fractured chat stepper, blank
editor body, "gemma" model bias, sheet over-blur, composer icons.

## Window chrome (gray void above traffic lights)

- `AnytypeShellView` now applies `.ignoresSafeArea(edges: .top)` so the cream chrome paints from
  `y=0` instead of starting ~28pt below the window edge. The previous SwiftUI safe area inset left
  the macOS title bar zone uncovered and showing AppKit vibrancy grey.
- `OWWindowChromeConfigurator` rewritten:
  - `lastAppliedRevision` defaults to `.max` so the first launch always applies.
  - New `OWWindowChromeProbeView` reacts to `viewDidMoveToWindow`, fixing the "configurator
    never saw a window before `updateNSView` finished" race.
  - Observers on `didBecomeKey`, `didChangeOcclusionState`, fullscreen enter/exit, backing
    properties, and `openWriteThemeDidChange` ensure chrome re-applies after every relevant
    AppKit lifecycle event.

## Chat status stepper (fractured circles)

- `OWChatStatusStepper` rebuilt with a single continuous rail (`LinearGradient` `Rectangle`)
  overlaid with dots at row centers. The old per-row `VStack { dot; connector }` left a 16pt
  visual gap between connector end and the next dot. Rail now seamlessly tints completed
  prefix with accent and falls back to subtle border below the active step.

## Blank editor body on Welcome

- `EditorView` no longer waits for `.onAppear` to populate `@State editingBlocks`. The new
  `init(document:)` and `init(documentID:)` seed body / header / cover snapshots synchronously
  so the first render already shows the welcome content.
- Removed `AnytypeShellView.editorLayoutEpoch` and the `.id(editorLayoutEpoch)` on the editor.
  Every rail / sidebar / assist toggle used to rebuild EditorView, wiping `editingBlocks` to
  `[]` until `.onAppear` re-fired. EditorView is now keyed only on `doc.id`.
- `AnytypeShellView.editorCenter` passes the full `VaultDocument` to `EditorView(document:)`
  instead of just the UUID, so the init snapshot reflects vault edits.

## LM Studio model resolution ("google/gemma-4-e4b · not checked")

- `LMStudioConfig.defaultChatModelID` is now empty (`""`). The composer caption reads
  "Not set · checking…" until `/v1/models` resolves the actually-loaded model.
- `LMStudioConfigPersistence.decode` clears legacy `"local-model"` *and* `"gemma-4-e4b"`
  placeholders so older installs auto-rebind to the first loaded model.
- `ContentView.task` kicks off `aiServices.checkConnection()` early via a detached task so the
  caption is honest before the user opens the chat panel.
- `OpenWriteAIServices.actionableChatError` 404 path no longer says `Load "Not set" in LM Studio`
  — it now suggests configuring a chat model when the field is empty.

## Sheet over-blur (Refine selection wipes the shell)

- `openWriteSheetPresentationChrome` switched to `.regularMaterial` backgrounds so the shell
  stays visible (translucent) behind sheets instead of dropping to a flat color.

## Composer polish

- `OWUnicodeIcon.wiki` changed from `⌁` (ELECTRIC ARROW — rendered as gibberish) to `◍`
  (CIRCLE WITH VERTICAL FILL — reads as globe/meridian) for the chat composer's web-fetch
  toggle.
- `DesignTokens.Layout.composerBoardIconSize` 18 → 20pt; addresses "composer icons small".

## Verification

- `xcodebuild -scheme OpenWrite -configuration Debug` (from `OpenWrite/`) → **BUILD SUCCEEDED** (2026-05-17, post-commit `282c0b7`).
- No new warnings; pre-existing `try?` / `var url` warnings unchanged.
- **§G manual acceptance not run** in this pass — user should verify on machine.

---

## Opus checklist status (2026-05-17 evening pass, commit `282c0b7`)

Honest status against the Opus P0/P1 list. **Fixed** = addressed in this sweep's diff; **Partial** = related change, user may still see issue; **Open** = not touched; **Unverified** = code changed, manual QA pending.

| Item | Status | Notes |
|------|--------|--------|
| Traffic lights gone + gray strip | **Fixed** (unverified) | `ignoresSafeArea`, `OWWindowChromeProbeView`, lifecycle observers |
| Preview-mode + properties stacking on body | **Open** | Not in this diff |
| Checkbox click navigates away + glyph alignment | **Open** | Not in this diff |
| Composer 2×2 board overlapping chat | **Partial** | Icon size 18→20pt; overlap/layout not changed |
| Editor scroll to bottom on Welcome | **Partial** | Blank body via sync `init`; scroll-to-bottom not targeted |
| Wikilink `[[Title]]` chips | **Open** | Not in this diff |
| Cmd-Z / Cmd-Shift-Z undo redo | **Open** | Not in this diff |
| Inline vault search + icon | **Partial** | Web-fetch glyph `◍`; dedicated search icon/tooltip not done |
| Theme switcher visibility | **Open** | Not in this diff |
| Refine sheet washing parent | **Fixed** (unverified) | `.regularMaterial` sheet chrome |
| LM Studio loaded-model detection + status pill | **Fixed** (unverified) | Empty default, persistence cleanup, early `checkConnection` |
| Build verification | **Pass** | `xcodebuild` Debug from `OpenWrite/` succeeded |
