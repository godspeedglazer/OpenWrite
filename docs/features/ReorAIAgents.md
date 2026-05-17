# Reor-inspired AI agents (clean-room Swift)

OpenWrite ports **behavior shapes** from [Reor](https://github.com/reorproject/reor) (`AgentConfig`, tool flags, example agents, chat with retrieval) as native Swift types. No AGPL TypeScript or Electron runtime is linked.

## Types

| File | Role |
|------|------|
| `Models/AgentConfig.swift` | `AgentConfig`, `AgentToolFlags` — name, `systemPrompt`, `chunkLimit`, tool flags |
| `AI/AgentRegistry.swift` | Built-in presets: **Research Q&A**, **Note Summarizer**, **Outline Helper** (+ `refineProse` for editor inline assist only) |
| `UI/AI/AgentPickerView.swift` | Menu picker bound to `OpenWriteAIServices.selectedAgentID` |
| `AI/VoiceInputService.swift` | Dictation stub; mic button in chat composer (Speech framework TODO) |

## Reor mapping

| Reor (`types.ts`) | OpenWrite |
|-------------------|-----------|
| `AgentConfig.name` | `AgentConfig.name` |
| `promptTemplate` (system + user) | Single `systemPrompt`; user message built in `RAGService.promptPayload` |
| `dbSearchFilters.limit` | `chunkLimit` → `effectiveChunkLimit` |
| `toolDefinitions[]` | `AgentToolFlags` (`useVaultRetrieval`, `allowCreateNote`, `passFullNoteContext`) |
| `passFullNoteIntoContext` | `passFullNoteContext` → wider snippet budget per chunk |

## Chat flow

1. User picks an agent in the vault chat header (`AgentPickerView`).
2. `ChatPanelModel.send` calls `rag.buildContext(query:agent:)` with that agent’s chunk limit and retrieval flag.
3. `rag.streamAnswer(context:agent:)` sends `agent.systemPrompt` as the LM Studio system message.
4. Assistant bubbles show retrieval hits as **Sources** (unchanged).

## Built-in agents

| ID | Name | Chunks | Notes |
|----|------|--------|-------|
| `research-qa` | Research Q&A | 12 | Default; cite `[chunk:UUID]` |
| `note-summarizer` | Note Summarizer | 16 | Wider excerpts (`passFullNoteContext`) |
| `outline-helper` | Outline Helper | 8 | Hierarchical outline output |
| `refine-prose` | Refine prose | 6 | Editor selection refine only (not in picker) |

## Tool flags (v1 / v2)

- **`useVaultRetrieval`** — On: hybrid search before answer. Off: model sees query only (no hits).
- **`allowCreateNote`** — Reserved for v2 `create_note` with confirmation UI.
- **`passFullNoteContext`** — Larger per-chunk snippet cap in the RAG user prompt.

## Voice input

`VoiceInputService` exposes `toggleListening(appendTo:)` for the composer mic control. Implementation is intentionally stubbed until Speech.framework entitlements and `NSSpeechRecognitionUsageDescription` are product-approved.

## Related

- [AI-Pipeline.md](../Architecture/AI-Pipeline.md) — RAG stages and safety caps
- [adr/0003-reor-rag-in-swift.md](../adr/0003-reor-rag-in-swift.md) — clean-room policy
