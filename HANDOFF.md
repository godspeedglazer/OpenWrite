# OpenWrite — Handoff pointer

**For Claude Opus 4.7 xhigh:** read the full execution brief here:

**[docs/HANDOFF.md](docs/HANDOFF.md)**

That document is the single source of truth: product intent, P0/P1 blockers (user-verified), git archaeology, file map, `OpenWriteAIServices` connection logic, phased plan, acceptance tests, anti-patterns, and parallel-agent coordination.

---

| Field | Value |
|-------|--------|
| **Branch** | `main` |
| **HEAD** | `8ba07f7` (after handoff commit; app code baseline `8c228e4`) |
| **Latest commit** | `8ba07f7` — docs: add Opus 4.7 resolution handoff for OpenWrite blockers |

```bash
cd /Users/erichspringer/Downloads/OpenWrite
git rev-parse HEAD
git log -5 --oneline
```

**Do not** assume commits fix user-reported P0 issues until [docs/HANDOFF.md §G](docs/HANDOFF.md#g-acceptance-tests-manual-qa) passes on a clean Debug build.

**Also:** [AGENT_PROMPT_UI_REFACTOR.md](AGENT_PROMPT_UI_REFACTOR.md) · [docs/design/UIRefactorBrief.md](docs/design/UIRefactorBrief.md)
