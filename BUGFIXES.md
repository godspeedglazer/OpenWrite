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

## Typography / anti-patterns

- Grep: no `Image(systemName:)`, `systemImage`, or bare `Font.body` in product Swift (code blocks use `OWTypography.code*`).
- `RelatedNotesView` and `PropertyInspectorView` aligned to design tokens.

## Not changed

- `VoiceInputService` TODO stubs (no crash paths).
- No git commit per request.
