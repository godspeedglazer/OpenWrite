# Agent prompt — UI refactor (Phase 0)

Paste or attach this when starting a UI refactor session. Mirror: [docs/AGENT_PROMPT_UI_REFACTOR.md](./docs/AGENT_PROMPT_UI_REFACTOR.md).

**Source of truth for all open issues (P0–P3), file paths, and acceptance criteria:** [docs/HANDOFF.md](./docs/HANDOFF.md) — *OpenWrite — Opus 4.7 xhigh Execution Handoff*. Pointer: [HANDOFF.md](./HANDOFF.md).

---

## EMERGENCY context (2026-05-17)

**Do not claim “fixed” without a clean rebuild and Activity Monitor check.**

### Current reality (verify on machine)

- **User reports P0 still open:** empty editor body, chat scroll broken, layout/RAM regressions possible — see [docs/HANDOFF.md §B](./docs/HANDOFF.md#b-p0-blockers-user-verified-screenshots).
- Commits (`dbb8f66`, `efd890b`, `8c228e4`, etc.) are **claims**, not verification — see [trust table](./docs/HANDOFF.md#whats-already-committed-honest-trust-table).

### How to verify

1. Quit OpenWrite. **Product → Clean Build Folder**. Debug build.
2. Editor tab + Welcome body visible. Idle CPU &lt; 15%, RAM not climbing past ~500 MB.
3. `git log -1` matches pulled commit.

### What agents did vs shipped

| Agents said | Shipped truth |
|-------------|----------------|
| “Theme changes are done” | Partially true — 13 themes shipped, but AppKit bridge propagation still needs explicit verification |
| “Chat scroll is fixed” | True for transcript clipping; conversation state is still capped in-memory + archived snapshot restore |
| “UI polish complete” | Not true — titlebar alignment and writing-surface edge behavior still need QA |

### Writing core (in scope)

`EditorView`, `OWBlockEditorView`, `BlockEditorPasteCaptureView`, launch selection — **stability only**. No Affine/Electron rewrite.

### Inline AI (in scope)

Right-click selection → `InlineRefinePreset` menu; toolbar Refine; `InlineAssistController` sheet. See [docs/design/InlineAIEditing.md](./docs/design/InlineAIEditing.md).

---

## Goal

Fix OpenWrite’s **download-ready perception**: Anytype **aesthetics** on **native SwiftUI** — not Electron.

## Read first (in order)

1. [HANDOFF.md](./HANDOFF.md) — **Opus 4.7 execution handoff** (P0–P3, acceptance criteria, file map)
2. [docs/design/UIRefactorBrief.md](./docs/design/UIRefactorBrief.md)
3. [docs/design/CurrentUIAudit.md](./docs/design/CurrentUIAudit.md)
4. [docs/design/FrontendPriorities.md](./docs/design/FrontendPriorities.md)

## Fix these P0 failures first

1. **Titlebar alignment:** verify `OWShellTitleBar` alignment for expanded rail, collapsed rail, and compact/narrow windows.
2. **Writing-engine safety:** preserve current measure/apply contract in `OWBlockEditorView`; avoid new per-keystroke layout loops.
3. **Chat state quality:** keep transcript scroll behavior stable while improving thread/state continuity.
4. **Theme propagation:** preserve 13-theme behavior and ensure AppKit-backed controls update on every theme switch.

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
