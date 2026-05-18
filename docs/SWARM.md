# OpenWrite — Correctness swarm guide

Practical orchestration for **parallel Cursor agents** hunting P0 bugs in this repo. The goal is **verified fixes**, not volume of patches. Parent agent stays alive; workers append evidence to a blackboard; nothing ships on `claimed` alone.

**Related:** in-repo agent stubs at [`.cursor/agents/`](../.cursor/agents/) (commit `38449e0`). Personal coordinator skill: `~/.cursor/skills/swarm-coordinator/SKILL.md` (not in this repo).

---

## When to use a swarm

| Situation | Approach |
|-----------|----------|
| Single obvious file / one-line root cause | **No swarm** — one agent, one verify command |
| P0 with multiple hypotheses (editor empty + chrome void + LM caption) | **Small swarm** (3–8 agents): 2–4 scouts → 1–2 builders → 1 verifier |
| User-reported regressions after many passes; need breadth | **50-agent mode** (see below): many scouts, top-K lanes, tournament merge |
| Plan-only, secrets in scope, dirty unowned tree | **Do not swarm** |

**50-agent mode** is for correctness under uncertainty (layout loops, connection state lies, scroll clipping). **Small swarm** is the default for OpenWrite P0 slices tied to [HANDOFF.md](./HANDOFF.md) §B.

---

## Phases (correctness swarm)

Coordinator owns the turn until a verifier reports `verified` or the turn is **blocked** with a user-visible reason.

```
Phase 0  Coordinator triage     → turn_manifest.json
Phase 1  Hypothesis scouts      → scout_card (readonly)
Phase 2  Squad synthesizers     → squad_digest (optional at scale)
Phase 2b Hypothesis ranker       → top_k (K ≤ 5)
Phase 3  Fix candidates          → patch_bundle + candidate (owned paths only)
Phase 4  Repro verifiers          → verify_report (readonly)
Phase 5  Red team (optional)      → break_report
Phase 6  Coordinator merge       → one winner; doc-sync may update HANDOFF
```

### Blackboard layout

Per turn, use a dedicated directory:

```
.cursor/swarm/<turn_id>/
  turn_manifest.json    # repro steps, owned paths, acceptance refs
  events.jsonl          # append-only artifact bus
```

Workers **append one JSON line** per deliverable. Coordinator **compacts** between phases (rank table, drop superseded hypotheses) — do not fan full worker stdout into parent context.

Example `scout_card` line:

```json
{
  "hypothesis_id": "H-042",
  "role": "scout_card",
  "files_touched": ["OpenWrite/OpenWrite/UI/Shell/OWWindowChrome.swift"],
  "claim": "Configurator never applies when window attaches after first updateNSView",
  "evidence": [{"type": "file", "ref": "OWWindowChromeConfigurator.refresh"}],
  "confidence": 0.78,
  "status": "hypothesis"
}
```

Valid statuses: `hypothesis` → `candidate` → `verified` | `rejected` | `superseded`. **`claimed` without `repro_log_ref` or `test_output_ref` is invalid for merge.**

---

## Agent roles (in-repo stubs)

| Agent | File | readonly | Delivers |
|-------|------|----------|----------|
| **hypothesis-scout** | [`.cursor/agents/hypothesis-scout.md`](../.cursor/agents/hypothesis-scout.md) | yes | `scout_card` — ranked claim + typed evidence |
| **fix-candidate** | [`.cursor/agents/fix-candidate.md`](../.cursor/agents/fix-candidate.md) | no* | `patch_bundle` + `candidate` in assigned worktree / `OWNED_PATHS` |
| **repro-verifier** | [`.cursor/agents/repro-verifier.md`](../.cursor/agents/repro-verifier.md) | yes | `verify_report` — pass/fail + log refs |

\*Builders must not commit, push, or edit `HANDOFF.md`. Coordinator merges one winning patch.

Spawn via Cursor **Task** tool with `subagent_type` matching the role (or custom agent name from `.cursor/agents/`). Use `run_in_background: true` in Multitask so the parent can poll the blackboard between waves.

---

## Coordinator rules (non-negotiable)

1. **No fire-and-forget** — parent polls `.cursor/swarm/<turn_id>/events.jsonl` and advances phases; do not spawn 20 tasks and exit.
2. **Verifier before claim** — no user-facing "fixed" until `verify_report` with command output (e.g. `xcodebuild`, manifest grep, manual step id).
3. **Single HANDOFF writer** — only doc-sync updates [HANDOFF.md](./HANDOFF.md); builders append blackboard cards only.
4. **Evidence over opinions** — scouts cite grep/file/call-path refs; verifiers attach logs.
5. **Disjoint ownership** — each builder lane gets explicit `OWNED_PATHS` globs or a **git worktree** branch; max ~5 concurrent writers for merge safety.

### Auto-efficiency (structure, not caps)

The protocol does **not** cap tokens, brief length, or turn size. Efficiency comes from:

- **JSONL blackboard** instead of chat fan-in
- **Squad digests** — coordinator reads manifest + digests + rank table, not 50 full transcripts
- **Unlimited readonly** scouts and verifiers
- **Bounded writers** only for merge safety
- **Early stop** when a cheap deterministic repro passes (build, grep assertion)
- **First verified wins** in tournament mode when repro is cheap

Briefs should still include structured sections: `TURN`, `ROLE`, `BLACKBOARD`, `OWNED_PATHS`, `DELIVERABLE`, `FORBIDDEN`, `SUCCESS` (see agent stub files).

---

## OpenWrite-specific repro manifest

Point verifiers at [HANDOFF.md §G](./HANDOFF.md#g-acceptance-tests-manual-qa). Minimum automated gate before manual QA:

```bash
cd OpenWrite
xcodebuild -scheme OpenWrite -configuration Debug build
```

Optional deterministic checks (add to `turn_manifest.json`):

- `rg 'systemName:|systemImage' OpenWrite/OpenWrite/UI` — zero matches (project rule)
- Grep for reintroduced `editorLayoutEpoch` or `defaultChatModelID = "gemma"`

Manual P0 checks (verifier documents pass/fail in `verify_report`, not prose):

- Welcome body visible; type 30s; idle RAM/CPU
- Chat scroll top ↔ bottom with 10+ messages
- Traffic lights + no gray void
- LM caption honest with server on/off

---

## 50-agent vs small swarm

| | Small swarm | 50-agent mode |
|--|-------------|----------------|
| Scouts | 2–4 | 20–30 |
| Builders | 1–2 lanes | top-K × 2–4 (K≤5), worktrees |
| Verifiers | 1–2 | 10–15 |
| When | Known subsystem, ≤3 files | Many competing hypotheses, user distrusts prior commits |
| Risk | Under-explore | Merge collisions — require worktrees + path ownership |

**Do not** spawn 50 agents for typos, single-file obvious fixes, or when the user forbids exploration without repro steps.

---

## Testing swarm mode in this repo

1. Pick a **single P0** from [HANDOFF.md §B](./HANDOFF.md#b-p0-blockers-user-verified-screenshots) (e.g. B4 chrome void).
2. Create `.cursor/swarm/test-2026-05-17/turn_manifest.json` with repro steps and `OWNED_PATHS`.
3. Launch 2× `hypothesis-scout` (different slices), 1× `fix-candidate` on top hypothesis, 1× `repro-verifier` with build command.
4. Coordinator reads `events.jsonl`; only merge if `status: verified`.
5. **Do not commit** blackboard dirs — add `.cursor/swarm/` to local ignore if needed; they are runtime artifacts.

---

## Related documents

| Doc | Use |
|-----|-----|
| [HANDOFF.md](./HANDOFF.md) | P0/P1 blockers, acceptance tests, trust table |
| [../BUGFIXES.md](../BUGFIXES.md) | Per-sweep fix log + Opus checklist status |
| [../HANDOFF.md](../HANDOFF.md) | Short pointer to this tree |
