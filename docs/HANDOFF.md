# OpenWrite — Handoff index

**Canonical execution brief (Opus 4.7 xhigh):** [../HANDOFF.md](../HANDOFF.md)

This page is a **short router** — all issue detail, acceptance criteria, and file paths live in the root document.

---

## Quick links by anchor

| Topic | Section in [../HANDOFF.md](../HANDOFF.md) |
|-------|------------------------------------------|
| Mission & scope | [Mission](../HANDOFF.md#mission) |
| Git HEAD & verify commands | [Current git state](../HANDOFF.md#current-git-state-how-to-verify) |
| SF Symbols, tokens, editor safety | [Non-negotiable constraints](../HANDOFF.md#non-negotiable-constraints) |
| **P0** empty body | [P0.1 Writing engine](../HANDOFF.md#p01--writing-engine-empty-body--blocks-not-rendering) |
| **P0** fork-bomb / RAM | [P0.2 Layout fork-bomb](../HANDOFF.md#p02--layout-fork-bomb-23-gb-ram-99-cpu) |
| **P0** chat scroll | [P0.3 Chat scroll](../HANDOFF.md#p03--chat-transcript-scroll-cannot-scroll-top-to-bottom) |
| **P0** blank launch / tab | [P0.4 Launch tab](../HANDOFF.md#p04--blank-editor-on-launch--wrong-center-tab-graph-vs-editor) |
| **P1** LM Studio / gemma caption | [P1.1–P1.2](../HANDOFF.md#p11--model-caption-shows-googlegemma-4-e4b--not-checked-need-live-lm-studio-detection) |
| **P1** stepper / connect lies | [P1.3–P1.4](../HANDOFF.md#p13--chat-stepper-overlap--yellow-errors) |
| **P1** Refine | [P1.5](../HANDOFF.md#p15--refine-sheet--menu-glitchy-select-text-inside-block) |
| **P1** composer icons / paste | [P1.6–P1.7](../HANDOFF.md#p16--chat-composer-icons-too-small-search-doesnt-look-like-search-mystery-second-button) |
| **P1** traffic lights / tab height | [P1.8–P1.9](../HANDOFF.md#p18--traffic-lights-misplaced-gray-void-where-system-lights-were) |
| **P1** sheets / themes | [P1.11–P1.12](../HANDOFF.md#p111--sheets-cover-settings-hide-entire-app--lavender-void) |
| **P2** RAG / indexing | [Priority 2 — RAG](../HANDOFF.md#priority-2--rag--ingestion) |
| **P2** themes / ObjectType | [Priority 2 — Themes](../HANDOFF.md#priority-2--themes) |
| **P3** dead code / Affine | [Priority 3](../HANDOFF.md#priority-3--dead-code--tech-debt) |
| File map | [Per-area file map](../HANDOFF.md#per-area-file-map) |
| Committed vs user truth | [What's already committed](../HANDOFF.md#whats-already-committed-honest--may-not-work-for-user) |
| QA checklist | [Regression checklist](../HANDOFF.md#regression-checklist-run-before-declaring-done) |
| 1–2 week plan | [Suggested implementation order](../HANDOFF.md#suggested-implementation-order-12-week-plan) |
| Deduped issue table | [Appendix A](../HANDOFF.md#appendix-a--user-reported-issue-consolidation-deduped) |

---

## Other entry points

| Role | Document |
|------|----------|
| UI refactor agent (Phase 0) | [AGENT_PROMPT_UI_REFACTOR.md](./AGENT_PROMPT_UI_REFACTOR.md) |
| Visual spec | [design/UIRefactorBrief.md](./design/UIRefactorBrief.md) |
| Brutal UI audit | [design/CurrentUIAudit.md](./design/CurrentUIAudit.md) |
| P0 product checklist | [design/FrontendPriorities.md](./design/FrontendPriorities.md) |
| Bug sweep log | [../BUGFIXES.md](../BUGFIXES.md) |
| Doc hub | [README.md](./README.md) |

---

**Last updated:** 2026-05-17 · **HEAD:** see `git log -1` on `main`
