# Documentation Standards

**Last updated:** 2026-05-17  
**Applies to:** All contributors and autonomous agents working in `OpenWrite/` and `docs/`

OpenWrite follows a **document everything** policy: shipping behavior, data formats, and architectural choices must be discoverable from [docs/README.md](../README.md) without reading the entire codebase.

---

## Core rules

### 1. Every feature PR updates documentation

Before merge, a user-visible feature PR MUST include at least one of:

| Change type | Required doc action |
|-------------|---------------------|
| New capability | New or updated `docs/features/<name>.md` |
| Behavior change to existing feature | Update corresponding feature doc + epic checkbox if applicable |
| NDL syntax | Update [NDL/Specification.md](../NDL/Specification.md) and [NDL/Migration.md](../NDL/Migration.md) if versioned |
| Vault / `.owdoc` schema | Update [Architecture/DataModel.md](../Architecture/DataModel.md) |
| AI / search pipeline | Update [Architecture/AI-Pipeline.md](../Architecture/AI-Pipeline.md) |
| UI pattern / tokens | Update `docs/design/` (when present) |

**Docs-only PRs** use commit prefix `docs:` per [GitWorkflow.md](../GitWorkflow.md).

### 2. Architectural changes require an ADR

Create an ADR in `docs/adr/` when a decision is:

- Hard to reverse (storage format, crypto algorithm, sync protocol)
- Cross-cutting (new top-level module, dependency rule change)
- Controversial (trade-off between simplicity and parity)

**Do not** duplicate the full [OpenWriteMasterPlan.md](../OpenWriteMasterPlan.md) in ADRs—link to it for context.

ADR template: [adr/README.md](../adr/README.md).

### 3. Link, don’t duplicate the master plan

[OpenWriteMasterPlan.md](../OpenWriteMasterPlan.md) remains the **single long-form vision** document. Other docs summarize and **link** to relevant sections (competitive matrix, privacy model, roadmap phases).

### 4. Docs must match code or be marked aspirational

| Status label | Meaning |
|--------------|---------|
| **Implemented** | Matches current `main` |
| **Partial** | Stub exists; behavior incomplete |
| **Planned** | Not yet in tree |

Use explicit status in feature docs and architecture tables (see [Architecture/Overview.md](../Architecture/Overview.md)).

### 5. No secrets in documentation

Never commit passphrases, API keys, real vault salts, or production URLs with credentials. Use placeholders: `http://127.0.0.1:1234`, `base64...`.

### 6. License attribution when porting reference code

OSI-licensed reference trees may contribute **code** into `OpenWrite/` when obligations are met. **Anytype (`anytype-ts-develop/`, ASAL)** remains **inspiration-only** — never port its source into the product.

| Source | License | When you port into `OpenWrite/` |
|--------|---------|----------------------------------|
| `reor-main/` | AGPL-3.0 | File header or adjacent comment: derived from Reor, AGPL-3.0, link to upstream commit/URL; ensure repo **NOTICE** / distribution meets **link/comply** (counsel for proprietary builds) |
| `logseq-master/` | AGPL-3.0 | Same as Reor |
| `massCode-main/` | AGPL-3.0 | Same as Reor |
| `AFFiNE-canary/` (MIT paths only) | MIT | SPDX + copyright line from upstream file; note AFFiNE path in PR |
| `rem-main/`, `rem/`, `REM*/` | MIT | Preserve Jason McGhee / fork copyright; note upstream path in PR |
| `anytype-ts-develop/` | ASAL | **Do not port** — document UX inspiration only in design docs |

**PR checklist for ports:**

- [ ] Feature doc or ADR mentions upstream inspiration (behavior + path), not just “similar to X”
- [ ] Ported Swift files carry correct license header or reference in root `NOTICE` (when added)
- [ ] AGPL ports: compliance plan noted in PR (linking, source offer, combined work)
- [ ] No Anytype source, assets, protos, or UI strings in the diff

---

## File placement guide

| Content | Location |
|---------|----------|
| Doc hub index | `docs/README.md` |
| System design | `docs/Architecture/` |
| NDL grammar | `docs/NDL/` |
| Product philosophy | `docs/ProductPhilosophy.md` |
| Epics & estimates | `docs/RoadmapEpics.md` |
| Feature specs | `docs/features/<kebab-name>.md` |
| ADRs | `docs/adr/NNNN-title.md` |
| UI/UX | `docs/design/` |
| Terms | `docs/Glossary.md` |
| Git conventions | `docs/GitWorkflow.md` |

---

## Feature document template

Create `docs/features/<name>.md` with:

```markdown
# Feature: <Title>

**Status:** Planned | Partial | Implemented  
**Epic:** [E-XX](../RoadmapEpics.md#e-xx-...)  
**Last updated:** YYYY-MM-DD

## Summary
One paragraph: what the user can do.

## User stories
- As a writer, I …

## Acceptance criteria
- [ ] Criterion 1

## Architecture
Links to Architecture/*.md, relevant Swift paths.

## Non-goals
What this feature explicitly does not do.

## Test plan
Manual and automated checks.
```

---

## ADR requirements

- Filename: `NNNN-short-title.md` (four-digit zero-padded)
- Status: Proposed → Accepted → Deprecated → Superseded
- Sections: Context, Decision, Consequences, Alternatives considered
- Link from [ProductPhilosophy.md](../ProductPhilosophy.md) or [docs/README.md](../README.md) when user-facing

---

## Review checklist (reviewers)

- [ ] `docs/README.md` index updated if new top-level doc
- [ ] Root [README.md](../../README.md) updated if user-facing entry point changes
- [ ] NDL/vault changes have migration notes
- [ ] Aspirational claims labeled Planned/Partial
- [ ] Reference ports: license headers / NOTICE updated; AGPL link/comply considered; **no Anytype (ASAL) code**
- [ ] Glossary updated for new terms

---

## Agent-specific instructions

Autonomous agents MUST:

1. Read [docs/README.md](../README.md) and [OpenWriteMasterPlan.md](../OpenWriteMasterPlan.md) before large changes.
2. Update docs in the **same PR** as code unless explicitly told docs-only follow-up.
3. Never modify vendored reference trees (`reor-main/`, etc.) for product features.
4. Use [Glossary.md](../Glossary.md) terminology consistently.

---

## Related documents

- [GitWorkflow.md](../GitWorkflow.md)
- [docs/README.md](../README.md)
- [adr/README.md](../adr/README.md)
