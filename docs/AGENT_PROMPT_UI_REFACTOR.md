# Agent prompt — UI refactor (Phase 0)

Paste or attach this when starting a UI refactor session. Root copy: [../AGENT_PROMPT_UI_REFACTOR.md](../AGENT_PROMPT_UI_REFACTOR.md).

**Source of truth for all open issues (P0–P3):** [HANDOFF.md](../HANDOFF.md) · [handoff index](./HANDOFF.md)

---

## Goal

Fix OpenWrite’s **download-ready perception**: Anytype **aesthetics** (filled UI, cover gallery, movable page icon, dense rail, submenus) on **native SwiftUI** — not Anytype’s Electron framework.

## Read first (in order)

1. [HANDOFF.md](../HANDOFF.md) — Opus 4.7 execution handoff (P0 blockers, acceptance criteria, file map)
2. [design/UIRefactorBrief.md](./design/UIRefactorBrief.md) — canonical spec, component order, acceptance
3. [design/CurrentUIAudit.md](./design/CurrentUIAudit.md) — area | status | fix
4. [design/FrontendPriorities.md](./design/FrontendPriorities.md) — P0 failed/partial checklist
5. [design/OWIcons.md](./design/OWIcons.md) — **Unicode only**
6. [design/Typography.md](./design/Typography.md) — Source Serif bundling

## Fix these P0 failures first

1. **Fonts:** macOS registration for Source Serif 4 in Xcode target; eliminate Release fallback banner (`OWTypography.verifyBundledFontsAtLaunch`).
2. **Blocks:** Stop clipping in `OWPreviewBlockRow` / block editor — multi-line growth inside `OWRoundedRect` cards.
3. **Page header:** `OWPageHeaderEditor` — emoji popover anchor, cover picker gallery, draggable icon, submenu for page options.
4. **Welcome fill:** Remove large void under type cards — template NDL or CTA row per [design/ReferenceUILayouts.md](./design/ReferenceUILayouts.md).

## Rules

- Do **not** add SF Symbols, Lucide, or Phosphor to product UI.
- Do **not** port Anytype TS/React code or assets.
- Match existing `DesignTokens` / `OWTypography` patterns.
- Only modify files required for the task; no drive-by refactors.
- Do **not** commit unless the user asks.

## Verify

- Build: `xcodebuild -scheme OpenWrite -configuration Debug` (and Release for font banner).
- Window **1200×800**: no font warning, unclipped blocks, emoji picker usable.
- Update [design/CurrentUIAudit.md](./design/CurrentUIAudit.md) when a row is fixed.

## Handoff index

[HANDOFF.md](./HANDOFF.md)
