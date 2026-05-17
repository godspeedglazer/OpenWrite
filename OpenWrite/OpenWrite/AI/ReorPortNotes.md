# Reor port notes (AGPL)

OpenWrite adapts **behavior** from [Reor](https://github.com/reorproject/reor) (`reor-main/` in this repo) as native Swift. No TypeScript, Electron, or Reor binaries are linked into the app.

## What was ported

| Reor source | OpenWrite target | Notes |
|-------------|------------------|-------|
| `src/lib/db.ts` — `keywordSearch`, `combineAndRankResults`, `hybridSearch` | `Core/Retrieval/HybridRanker.swift`, `RetrievalService.swift` | Default `vectorWeight` 0.7; keyword scoring on vector pool; stop words; fused ranking |
| `electron/main/common/chunking.ts` | `Core/Indexing/IndexChunk.swift` (`TextChunker`) | Heading-bounded chunks; recursive split when text &gt; `indexChunkMaxChars` (1000); overlap 20 |
| `src/lib/llm/tools/tool-definitions.ts` | `AI/AgentRegistry.swift`, `AgentConfig.swift` | Tool metadata (`AgentToolDefinition`); built-in agents; v1 executes retrieval only |

## AGPL-3.0 obligations

Reor is licensed under **AGPL-3.0**. Adapted Swift files carry `SPDX-License-Identifier: AGPL-3.0-or-later` in their headers.

If you distribute OpenWrite (source or binary):

1. **Source offer** — Provide corresponding source for OpenWrite, including these adapted files.
2. **License notice** — Retain copyright and AGPL notices on adapted files.
3. **Network use** — If users interact with a modified version over a network, AGPL may require offering source to those users (consult counsel for your deployment model).

**Dynamic linking / separate module:** Today the adapted logic lives in the main app target (statically compiled). If it is later extracted into a **separately distributed** framework or helper binary, that component should remain under AGPL and this file should document how it is linked (e.g. dynamic framework embedded in the app bundle).

## Clean-room boundary

- Reor TypeScript is **not** copied into production Swift verbatim.
- Comments cite Reor paths for traceability only.
- LM Studio, vault storage, and UI are OpenWrite-native.

## Not ported (intentional)

- Electron IPC, LanceDB schema, `date-fns` timestamp SQL filters (future: vault modified-date filters on search).
- Langchain npm dependency (recursive split reimplemented in Swift).
- Live tool execution for `createNote`, `readFile`, etc. (flags + definitions only; v2).
