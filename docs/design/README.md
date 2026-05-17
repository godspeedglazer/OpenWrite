# OpenWrite Design Language

**Version:** 1.0  
**Last updated:** 2026-05-17  
**Platform:** macOS 14+ · SwiftUI  
**Implementation:** `OpenWrite/Design/DesignTokens.swift`

This folder is the canonical reference for how OpenWrite looks, moves, and behaves in the interface. It complements product architecture in [`docs/OpenWriteMasterPlan.md`](../OpenWriteMasterPlan.md) and implementation epics in [`docs/RoadmapEpics.md`](../RoadmapEpics.md).

---

## Purpose

OpenWrite is a **local-first writer**: encrypted vault, block-structured notes (NDL), graph-native linking, and optional local AI via LM Studio. The design language exists so every screen feels like one product—native to macOS, calm under long writing sessions, and unmistakably **author-first** (you write; the machine retrieves and suggests).

These documents are written for:

- Engineers implementing SwiftUI views and AppKit bridges
- Designers prototyping flows in Figma or Keynote
- Agents extending the workbench shell, editor, or capture surfaces

**Clean-room policy:** Learn from competitors for *behavior* and *information architecture* only. Do not copy Anytype assets, color palettes, typography, or UI strings. OpenWrite’s visual identity is defined here.

---

## Document map

| Document | Contents |
|----------|----------|
| [**BrandAndLogo.md**](./BrandAndLogo.md) | Logo concept directions, accent colors, app icon sizes, Figma handoff, Notion-simple rules |
| [**OpenWriteDesignLanguage.md**](./OpenWriteDesignLanguage.md) | Principles, visual identity, macOS native feel, layout grammar, content tone |
| [**Tokens.md**](./Tokens.md) | Semantic colors, typography scale, 4pt spacing grid, radius, shadows; Swift name mapping |
| [**Components.md**](./Components.md) | Sidebar, workbench tabs, inspector, note editor, capture sheet, graph, AI panel, vault states |
| [**Motion.md**](./Motion.md) | Durations, curves, reduced motion, window/sheet transitions |
| [**Accessibility.md**](./Accessibility.md) | VoiceOver, contrast, keyboard, focus, Dynamic Type limits |

---

## Reading order

1. **OpenWriteDesignLanguage.md** — Read once when joining the project; revisit when making structural UI decisions.
2. **BrandAndLogo.md** — Use when designing or exporting the app icon, wordmark, or marketing lockups in Figma.
3. **Tokens.md** — Keep open while styling; every visual constant should trace to `DesignTokens`.
4. **Components.md** — Use when building or reviewing a specific surface.
5. **Motion.md** + **Accessibility.md** — Consult before shipping animations or new interactive controls.

---

## Relationship to code

| Design artifact | Code location |
|-----------------|---------------|
| Token names & values | `OpenWrite/Design/DesignTokens.swift` |
| Global accent (asset) | `Assets.xcassets/AccentColor.colorset` — should match `DesignTokens.Color.accent` |
| App icon | `Assets.xcassets/AppIcon.appiconset` — see [BrandAndLogo.md](./BrandAndLogo.md); regenerate placeholder via `scripts/generate_app_icon_placeholder.sh` |
| Workbench navigation | `UI/Workbench/SidebarSection.swift`, `WorkbenchState.swift` |
| Root shell (current) | `UI/ContentView.swift` — evolves toward full workbench per Components spec |
| Editor | `UI/EditorView.swift` |
| Capture | `UI/Capture/QuickCaptureController.swift` |

When docs and code disagree, **update docs first** if the code reflects an intentional experiment; otherwise align code to docs before release.

---

## Design principles (summary)

| Principle | Meaning in UI |
|-----------|----------------|
| **Local** | No “cloud loading” chrome; progress is honest (indexing, unlock, LM Studio reachability). Offline is normal, not an error state. |
| **Calm** | Low visual noise, generous whitespace, restrained color. Urgency uses typography and placement before red fills. |
| **Author-first** | Editor is the hero; AI and graph are companions in the inspector or secondary columns—not full-screen takeovers by default. |

Full rationale: [OpenWriteDesignLanguage.md § Principles](./OpenWriteDesignLanguage.md#principles).

---

## Versioning

- **Major** (2.0): Breaking token renames or principle changes.
- **Minor** (1.1): New components, new tokens, expanded guidance.
- **Patch** (1.0.1): Clarifications, contrast fixes, no API break.

Document changes in this folder’s git history; link PRs to affected epics (e.g. E-08 Workbench shell).

---

## Quick links

- Master plan: [../OpenWriteMasterPlan.md](../OpenWriteMasterPlan.md)
- Roadmap epics: [../RoadmapEpics.md](../RoadmapEpics.md)
- Git workflow: [../GitWorkflow.md](../GitWorkflow.md)
