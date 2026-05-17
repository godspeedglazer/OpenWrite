# ADR 0001: Local-only architecture

**Status:** Accepted  
**Date:** 2026-05-17  
**Deciders:** OpenWrite core team

## Context

Personal knowledge tools increasingly require accounts, cloud sync, and vendor-hosted AI. OpenWrite targets writers who want **ownership** of their corpus, offline editing, and predictable privacy on macOS.

Competitors (Anytype, Notion, cloud PKMs) optimize for multi-device sync and collaboration. OpenWrite v1 optimizes for **single-machine** depth: encryption, native UX, and local LM Studio.

## Decision

1. The **source of truth** is an on-disk `.openwrite` vault bundle owned by the user.
2. **No OpenWrite account** or mandatory network service in v1.
3. Core editing, indexing, graph, and encryption run **on device**.
4. Network access is **opt-in** and limited to user-configured endpoints (default: LM Studio on `localhost`).
5. Sync, if added in v2+, must be an **explicit optional module** with E2E encryption—not a retrofit that weakens local-first guarantees.

## Consequences

**Positive**

- Simpler threat model and UX (no sign-in funnel).
- Works offline for writing and reading.
- Aligns with [ProductPhilosophy.md](../ProductPhilosophy.md) pillar “local-only is the default.”

**Negative**

- No multi-device parity in v1.
- User responsible for backup (Time Machine, manual copy).
- Collaboration deferred.

## Alternatives considered

| Alternative | Why rejected for v1 |
|-------------|---------------------|
| Cloud-primary vault | Violates privacy and offline goals |
| Optional sign-in for “free sync” | Scope creep; competes on wrong axis |
| IPFS / P2P default | Complexity; Anytype already owns mesh narrative |
| iCloud Drive as source of truth | Conflicts with encrypted bundle design |

## References

- [OpenWriteMasterPlan.md § Principles](../OpenWriteMasterPlan.md#principles)
- [Architecture/DataModel.md](../Architecture/DataModel.md)
- [RoadmapEpics.md § E-01](../RoadmapEpics.md#e-01-vault-encryption-v1)
