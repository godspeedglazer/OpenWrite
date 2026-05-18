# Editor and AI panel placement

**Version:** 1.4  
**Last updated:** 2026-05-17  
**Status:** Implemented shell pattern with known edge risks  
**Code:** `AnytypeShellView.swift`, `AIAssistStripView.swift`, `ChatPanelView.swift`, `EditorView.swift`, `OWWindowChrome.swift`

---

## Current layout (shipped)

| Surface | Placement in app | Notes |
|---------|------------------|-------|
| **Primary writing** | Center card (`EditorView`) | Stays dominant; editor body uses SwiftUI `ScrollView` |
| **Vault chat** | Optional trailing assist strip (`AIAssistStripView` → `ChatPanelView`) | Collapsed by default; expands from bottom bar |
| **Related notes / Past Writes** | Same assist strip navigation stack | Not shown as a permanent third workbench column |
| **Inline refine** | Selection menu + toolbar button in editor | Uses `InlineAssistController` result sheet and apply path |
| **LM Studio + index controls** | Settings surfaces, not core rail chrome | Operational controls stay out of primary writing flow |

---

## Known issues and risks

| Area | Reality in code | Status |
|------|-----------------|--------|
| **Chat scroll behavior** | Transcript clipping fix shipped via `ChatTranscriptScrollView`; auto-scroll only when sentinel reports pinned-to-bottom | **Shipped fix** |
| **Chat conversation state** | In-memory transcript is capped (`maxInMemoryMessages = 48`); archived thread load is read-only snapshot replay | **Open risk** |
| **Titlebar alignment** | `OWShellTitleBar` centering/brand alignment changes with rail state and compact width heuristics | **Open visual QA risk** |
| **Writing-engine correctness** | AppKit block host remains custom measure/apply bridge; inline refine apply still relies on range/string fallback | **Open risk** |

---

## What shipped vs planned

| Area | Shipped on `main` | Still planned |
|------|-------------------|---------------|
| **Shell structure** | Custom rail + center card + collapsible assist strip in `AnytypeShellView` | Additional polish for compact/fullscreen edge layouts |
| **Editor stability** | SwiftUI editor scroll + measured AppKit host height bridge | Rich outliner interactions and deeper block operations |
| **Chat UX** | Honest connect/stream progression, transcript scroll fix, error/stepper cleanup | Durable thread persistence model and expanded state restoration |
| **Inline AI** | Selection refine menu/toolbar + result sheet + apply button | More deterministic apply semantics for every selection edge case |

---

## Implementation notes

- **Author-first default:** `WorkbenchState.aiAssistExpanded` starts false; center writing card is the default focal surface.
- **Assist strip collapse behavior:** `OWShellLayout.shouldAutoCollapseAssist` collapses strip when width budget cannot safely fit editor minimums.
- **Chat transcript model:** `ChatPanelView` hashes structural state (`chatScrollToken`) and only scrolls when pinned; this avoids token-by-token jumpiness.
- **Editor model:** `EditorView` uses SwiftUI `ScrollView`; `OWBlockEditorView` keeps a `laidOutHeight` binding synchronized to AppKit measurement.

---

## Contributor verification checklist

1. Launch with clean Debug build and open Welcome in the center editor.
2. Expand/collapse assist strip and confirm editor width remains usable.
3. Test chat with LM Studio off and on; verify timeout/error and streaming step transitions.
4. Scroll chat up, send another turn, verify transcript does not yank to bottom unless re-pinned.
5. Check titlebar/tab alignment with rail expanded, rail collapsed, and narrow windows.
6. Exercise inline refine and confirm selected text replacement behavior in real blocks.

---

## References

- [InlineAIEditing.md](./InlineAIEditing.md)
- [FrontendPriorities.md](./FrontendPriorities.md)
- [CurrentUIAudit.md](./CurrentUIAudit.md)
- [../HANDOFF.md](../HANDOFF.md)
