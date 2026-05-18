# Agent prompt — UI refactor (Phase 0)

Paste or attach this when starting a UI refactor session. Mirror: [docs/AGENT_PROMPT_UI_REFACTOR.md](./docs/AGENT_PROMPT_UI_REFACTOR.md).

---

## EMERGENCY context (2026-05-17)

**Do not claim “fixed” without a clean rebuild and Activity Monitor check.**

### KNOWN BROKEN (until verified on machine)

- Welcome / editor **layout fork-bomb** (CPU 99%, RAM GB+) — was NSScrollView ↔ block host + 1pt intrinsic collapse.
- **Blank white editor** on launch — same loop or nil selection / wrong center tab.
- **Commits `99d9da1` / `706218e` were insufficient alone** on user builds — editor now uses SwiftUI `ScrollView`.

### How to verify

1. Quit OpenWrite. **Product → Clean Build Folder**. Debug build.
2. Editor tab + Welcome body visible. Idle CPU &lt; 15%, RAM not climbing past ~500 MB.
3. `git log -1` matches pulled commit.

### What agents did vs shipped

| Agents said | Shipped truth |
|-------------|----------------|
| “HANDOFF updated” | Often stale HEAD; root prompt was deleted locally |
| “99d9da1 fixes 23GB” | Partial — loop could persist until editor scroll + intrinsic fix |
| “Welcome stable” | Required **behavior** change, not comments only |

### Writing core (in scope)

`EditorView`, `OWBlockEditorView`, `BlockEditorPasteCaptureView`, launch selection — **stability only**. No Affine/Electron rewrite.

### Inline AI (in scope)

Right-click selection → `InlineRefinePreset` menu; toolbar Refine; `InlineAssistController` sheet. See [docs/design/InlineAIEditing.md](./docs/design/InlineAIEditing.md).

---

## Goal

Fix OpenWrite’s **download-ready perception**: Anytype **aesthetics** on **native SwiftUI** — not Electron.

## Read first (in order)

1. [HANDOFF.md](./HANDOFF.md) — KNOWN BROKEN + verify steps
2. [docs/design/UIRefactorBrief.md](./docs/design/UIRefactorBrief.md)
3. [docs/design/CurrentUIAudit.md](./docs/design/CurrentUIAudit.md)
4. [docs/design/FrontendPriorities.md](./docs/design/FrontendPriorities.md)

## Fix these P0 failures first

1. **Fonts:** Source Serif 4 in Xcode target; no Release fallback banner.
2. **Blocks:** Stop clipping in `OWPreviewBlockRow`.
3. **Page header:** emoji popover, cover gallery, draggable icon.
4. **Editor stability:** never reintroduce `OpenWriteThemedScrollView` around `EditorView` document body.

## Rules

- **Unicode icons only** — [docs/design/OWIcons.md](./docs/design/OWIcons.md).
- Do **not** port Anytype TS/React.
- Match `DesignTokens` / `OWTypography`.
- **Do not** call `scheduleRefreshDocumentSize` on every editor update.
- Only commit when the user asks.

## Verify

```bash
cd OpenWrite/OpenWrite && xcodebuild -scheme OpenWrite -configuration Debug build -derivedDataPath /tmp/OpenWriteDerived
```

Activity Monitor on Welcome (60s idle). Update [docs/design/CurrentUIAudit.md](./docs/design/CurrentUIAudit.md) when a row is fixed.
