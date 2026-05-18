# OpenWrite — Handoff pointer

**For Claude Opus 4.7 xhigh:** read the full execution brief here:

**[docs/HANDOFF.md](docs/HANDOFF.md)**

That document is the single source of truth: product intent, P0/P1 blockers (user-verified), git archaeology, file map, `OpenWriteAIServices` connection logic, phased plan, acceptance tests, anti-patterns, and parallel-agent coordination.

---

| Field | Value |
|-------|--------|
| **Branch** | `main` |
| **HEAD** | see `git rev-parse HEAD` |
| **App fixes** | `282c0b7` — Opus P0/P1 evening sweep (chrome, editor, chat, LM Studio) |
| **Swarm** | [docs/SWARM.md](docs/SWARM.md) · agent defs `38449e0` in `.cursor/agents/` |

```bash
cd /Users/erichspringer/Downloads/OpenWrite
git rev-parse HEAD
git log -5 --oneline
```

**Do not** assume commits fix user-reported P0 issues until [docs/HANDOFF.md §G](docs/HANDOFF.md#g-acceptance-tests-manual-qa) passes on a clean Debug build.

**Also:** [docs/SWARM.md](docs/SWARM.md) (parallel bug hunts) · [AGENT_PROMPT_UI_REFACTOR.md](AGENT_PROMPT_UI_REFACTOR.md) · [docs/design/UIRefactorBrief.md](docs/design/UIRefactorBrief.md) · [BUGFIXES.md](BUGFIXES.md) (Opus checklist table)
