# ADR 0003: Reor-style RAG in Swift (clean-room)

**Status:** Accepted  
**Date:** 2026-05-17  
**Deciders:** OpenWrite core team

## Context

OpenWrite adopts the **dual-generator** thesis from Reor: humans write durable notes; LLMs retrieve and answer from that corpus. Reor ships as AGPL Electron + React + LanceDB; OpenWrite is a proprietary-friendly native macOS app and cannot commingle AGPL runtime code.

Users want **local** Q&A, related notes, and hybrid search without cloud models by default.

## Decision

1. **Reimplement** RAG pipeline in Swift: chunk → index → embed → hybrid retrieve → prompt → cite.
2. Use **LM Studio** OpenAI-compatible API instead of bundled Ollama.
3. Use **SQLite/GRDB + vector extension** (or equivalent) instead of LanceDB in Node—exact store TBD in E-04/E-05.
4. Study `reor-main/` for **behavior and algorithms only**; no source paste into `OpenWrite/`.
5. **`RAGService`** returns `RAGAnswer` with `citations: [RetrievalHit]` mandatory for user-facing answers.
6. **No** background upload of full vault; indexing triggered by save or explicit rebuild.

## Consequences

**Positive**

- Legally separable from Reor codebase.
- Native performance and Keychain-integrated privacy story.
- Aligns with [Architecture/AI-Pipeline.md](../Architecture/AI-Pipeline.md).

**Negative**

- Engineering cost to port chunking and hybrid rank.
- Feature lag vs Reor until E-03/E-05 complete.
- Users must run LM Studio separately.

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Embed Reor Electron | AGPL + non-native UX |
| Cloud RAG (OpenAI only) | Violates local-first default |
| No AI in v1 | Core differentiator vs Obsidian |
| MLX embedded in app | Scope; LM Studio already user-standard |

## References

- [OpenWriteMasterPlan.md § Reor](../OpenWriteMasterPlan.md#reor-foundation--agpl-clean-room-swift)
- [Architecture/AI-Pipeline.md](../Architecture/AI-Pipeline.md)
- [RoadmapEpics.md § E-03](../RoadmapEpics.md#e-03-lm-studio-rag)
- `OpenWrite/OpenWrite/AI/RAGService.swift`
