# OpenWrite UI Anti-Patterns

**Version:** 1.0  
**Last updated:** 2026-05-17  
**Audience:** Design, engineering, and agents  
**Canonical rules:** [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) · [OWComponents.md](./OWComponents.md)

This document lists **forbidden** UI patterns. If a pull request introduces any row below without an explicit ADR exception, reject it or refactor before merge.

---

## Platform chrome masquerading as product UI

| Anti-pattern | Why it fails | Use instead |
|--------------|--------------|-------------|
| **SF Symbols** (`Image(systemName:)`, `Label(..., systemImage:)`) in product surfaces | Reads as stock macOS utility; breaks distinct OpenWrite identity | `OWIcon` + bundled SVG/PDF assets ([OWComponents.md § OWIcon](./OWComponents.md#owicon)) |
| **Apple HIG default sidebar `List`** with system selection blue | Wrong density and selection metaphor | `OWSidebarRow` on `sidebarBackground` |
| **Grouped `Form` / `Section` in the editor column** | Settings-app layout in the writing surface | `OWPageHero` + NDL block stack + `OWRoundedRect` property strips |
| **System `.borderedProminent` / accentColor blue** as primary brand actions | User’s macOS accent ≠ OpenWrite accent | `OWButton` primary variant with `DesignTokens.Color.accent` |
| **`.buttonStyle(.bordered)` toolbars** as the main nav metaphor | Capsule chrome dominates calm rail | Plain `Button` + `OWIcon` in custom toolbar regions |
| **Vibrancy / `Material` stacks** in workbench body | Blur fights paper-like editor canvas | Flat `editorCanvas` + `surface` tokens |
| **`ContentUnavailableView` with system symbol** | Bundled SF artwork in empty states | `OWPageHero` `.emptyState` with `OWIcon` |
| **Stock `Picker` / `Menu` labels** with SF leading icons | Inconsistent stroke weight vs custom set | `OWIcon` + `Typography.*` labels |

**Allowed platform exceptions (narrow):**

- Native **alerts**, **file panels**, and **Settings** scene chrome where AppKit owns control drawing.
- **Standard scrollbars** and **text caret** (do not custom-draw).
- **VoiceOver** and **keyboard** behaviors from macOS; labels must still name actions in OpenWrite copy.

---

## Layout and proportion

| Anti-pattern | Why it fails | Use instead |
|--------------|--------------|-------------|
| **Inspector ≥ 50% of content width** at default window | AI competes with author ([ProductDirection.md](./ProductDirection.md)) | Inspector collapsed by default; cap at `inspectorMaxWidth` (360pt) |
| **LM Studio block in left rail** above vault list | Operator config in primary nav | Settings (`Cmd+,`) or compact footer strip |
| **Full-screen AI on launch** | Author-first violation | Restore last note; inspector closed |
| **Triple fixed columns on narrow windows** | Clips editor below `mainMinWidth` | Collapse inspector first, then sidebar ([Resize rules](./ProductDirection.md#resize-rules)) |
| **Hard-coded `Color.red` / `Color.blue`** | Breaks semantic tokens and dark mode | `danger`, `accent`, `ObjectType.accent(for:)` |

---

## AI surfaces

| Anti-pattern | Why it fails | Use instead |
|--------------|--------------|-------------|
| **Vault chat with no back stack** when drilling into agent/source detail | User trapped in sub-panel | `OWAIPanelHeader` back control ([ProductDirection.md § AI panels](./ProductDirection.md#ai-panels-back-navigation)) |
| **Duplicating chat in refine sheet** | Two generators, one confused surface | Inline popover for refine; inspector for vault Q&A ([EditorAndAIPanel.md](./EditorAndAIPanel.md)) |
| **Generic “Something went wrong”** for LM Studio | Hides local-first diagnosis | “LM Studio unreachable at {host}” + retry |

---

## Typography and iconography

| Anti-pattern | Why it fails | Use instead |
|--------------|--------------|-------------|
| **San Francisco as default UI font** in chrome | Indistinguishable from Apple apps | Bundled UI face via `DesignTokens.Typography` → `Font.ow*` |
| **Mixed icon sets** (SF + custom + emoji in nav) | Uneven visual weight | `OWIcon` catalog only; emoji reserved for page icons in hero |
| **Arbitrary icon sizes** (14pt, 22pt) | Misaligned baselines | `sidebarRowIconSize` (18), hero (48), toolbar (20) |

---

## Motion and feedback

| Anti-pattern | Why it fails | Use instead |
|--------------|--------------|-------------|
| **Per-keystroke animation** | Distracting during writing | [Motion.md](./Motion.md) budget |
| **Splash gate blocking edit** during full-vault index | Reor-style friction | Toolbar progress + background index |
| **Toast spam** for every save | Noise | Inline caption or subtle toolbar check |

---

## Competitor and legal

| Anti-pattern | Why it fails | Use instead |
|--------------|--------------|-------------|
| **Anytype assets, hex, or copy** | ASAL / trademark risk | Clean-room patterns in [AnytypeUIInspiration.md](./AnytypeUIInspiration.md) |
| **Importing reference-repo UI code** | License contamination | Port behavior to Swift in `OpenWrite/` only |

---

## Review gate

Before merging UI work, confirm:

- [ ] No `systemName:` / `systemImage:` in `OpenWrite/UI/**` (except documented platform exceptions)
- [ ] Typography uses bundled fonts through `DesignTokens.Typography`
- [ ] AI sub-panels expose back navigation when depth &gt; 1
- [ ] Column widths respect [ProductDirection.md § Resize rules](./ProductDirection.md#resize-rules)
- [ ] No grouped `Form` in editor or inspector **content** bodies

---

*See also: [OpenWriteDesignLanguage.md § Anti-patterns](./OpenWriteDesignLanguage.md#anti-patterns)*
