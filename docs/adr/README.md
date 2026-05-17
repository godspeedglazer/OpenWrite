# Architecture Decision Records (ADR)

**Last updated:** 2026-05-17

ADRs capture significant, hard-to-reverse technical decisions for OpenWrite. They complement the [master plan](../OpenWriteMasterPlan.md) (vision) and [Architecture/](../Architecture/) docs (structure).

---

## Index

| ID | Status | Title |
|----|--------|-------|
| [0001](./0001-local-only-architecture.md) | Accepted | Local-only architecture |
| [0002](./0002-typed-pages-object-model.md) | Accepted | Typed pages without cloud sync |
| [0003](./0003-reor-rag-in-swift.md) | Accepted | Reor-style RAG in Swift (clean-room) |

---

## When to write an ADR

See [Contributing/DocumentationStandards.md](../Contributing/DocumentationStandards.md).

---

## Template

```markdown
# ADR NNNN: Title

**Status:** Proposed | Accepted | Deprecated | Superseded by ADR-XXXX  
**Date:** YYYY-MM-DD  
**Deciders:** …

## Context
What problem or force motivates this decision?

## Decision
What we will do.

## Consequences
Positive and negative outcomes.

## Alternatives considered
What we rejected and why.
```

---

## Status lifecycle

1. **Proposed** — Under discussion in PR.
2. **Accepted** — Merged; implement accordingly.
3. **Deprecated** — No longer recommended; historical reference.
4. **Superseded** — Replaced by newer ADR; link forward.
