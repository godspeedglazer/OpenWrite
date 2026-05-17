# Agents and dictation

**Last updated:** 2026-05-17  
**Epic:** E-03 LM Studio RAG  
**Status:** v1 (presets + RAG wiring; tools and speech stubbed)

---

## Summary

Vault chat uses **agent presets** that control the LM Studio system prompt and how many indexed chunks are retrieved. Behavior is inspired by Reor’s `AgentConfig` / example agents (clean-room Swift only; no AGPL source in the app).

Dictation is defined as a **protocol** with a **no-op** implementation for v1. `VoiceInputService` remains a SwiftUI-friendly placeholder for a future microphone button; `DictationService` is the lower-level hook for streaming transcripts.

---

## Agent model

| Field | Purpose |
|-------|---------|
| `id` | Stable preset identifier |
| `name` | UI label in the chat header picker |
| `systemPrompt` | `role: system` message in `LiveRAGService.streamAnswer` |
| `chunkLimit` | Retrieval cap (`dbSearchFilters.limit` analogue), clamped to `AISafetyLimits.maxContextChunks` |
| `toolFlags.useVaultRetrieval` | When true, hybrid search runs before generation |
| `toolFlags.allowCreateNote` | Reserved for v2 tool execution with confirmation |
| `toolFlags.passFullNoteContext` | Wider per-chunk excerpts in the RAG user prompt |

**Code:** `OpenWrite/OpenWrite/AI/AgentConfig.swift`, `BuiltInAgents.swift`

---

## Built-in presets

| Preset | Use case | Chunk limit |
|--------|----------|-------------|
| **Research Q&A** | Default vault Q&A with citations | 12 |
| **Summarize selection** | Tight summaries from retrieved notes | 8 |
| **Refine prose** | Clarity and grammar; also used by inline refine | 6 |

Inline **Refine selection** in the editor calls `RAGService.answer` with **Refine prose**, independent of the chat picker.

---

## UI

- **Agent picker:** `UI/AI/AgentPickerView.swift` in the vault chat header (`ChatPanelView`).
- Selection is stored on `OpenWriteAIServices.selectedAgentID`.

---

## RAG integration

1. `buildContext(query:agent:)` uses `agent.effectiveChunkLimit` when `agent.toolFlags.useVaultRetrieval` is true.
2. `streamAnswer(context:agent:)` sends `agent.systemPrompt` as the system message to LM Studio.

---

## Dictation (v1 stub)

- **Protocol:** `DictationService` — `start(onPartial:onFinal:)`, `stop()`, `isListening`.
- **v1 implementation:** `NoOpDictationService` on `OpenWriteAIServices.dictation`.
- **UI placeholder:** `VoiceInputService` (not wired to Speech.framework yet).

See comments in `AI/DictationService.swift`.

---

## v2 (not in scope)

- Execute Reor-shaped tools: `search`, `createNote` with confirmation UI.
- User-defined agents persisted in vault settings.
- Wire dictation button in chat composer to `DictationService`.

---

## Related

- [Architecture/AI-Pipeline.md](../Architecture/AI-Pipeline.md)
- [adr/0003-reor-rag-in-swift.md](../adr/0003-reor-rag-in-swift.md)
- [Glossary.md § Agent](../Glossary.md)
