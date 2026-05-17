# OpenWrite UI Anti-Patterns

**Version:** 1.1  
**Last updated:** 2026-05-17  
**Audience:** Design, engineering, and agents  
**Canonical rules:** [FrontendPriorities.md](./FrontendPriorities.md) · [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) · [OWComponents.md](./OWComponents.md)

This document lists **forbidden** UI patterns. If a pull request introduces any row below without an explicit ADR exception, reject it or refactor before merge.

---

## HIG ordering and “stock Mac” IA

| Anti-pattern | Why it fails | Use instead |
|--------------|--------------|-------------|
| **`NavigationSplitView` sidebar as system `List`** with blue selection | Apple’s staple; reads as unfinished utility; user called this out explicitly | **`OWNavigationRail`** + `OWSidebarRow` on `sidebarBackground` ([FrontendPriorities.md § 1](./FrontendPriorities.md#1-abandon-hig-ordering-not-just-symbols)) |
| **Settings.app section order** in the rail | Wrong product IA | **OBJECTS → DATABASES → VAULT** with serif small-caps labels |
| **Stock `NSSearchField` / search bar chrome** in primary nav | HIG affordance overload | Custom flat search field + `OWIcon` |
| **Grouped `Form` / `Section` in the editor column** | Settings-app layout in the writing surface | `OWPageHero` + `OWPageBanner` + NDL block stack + `OWRoundedRect` strips |
| **Huge empty center column** (placeholder text only) | “Turn off” for users who want pretty, working UI | Dense CTAs: **+ New row**, type sheet, filled preview blocks |
| **Inter/SF-only chrome** with no serif voice | Indistinguishable from default Mac apps; “weird fonts” without intent | Bundled **serif** for display + section labels ([Typography.md](./Typography.md)) |

---

## Platform chrome masquerading as product UI

| Anti-pattern | Why it fails | Use instead |
|--------------|--------------|-------------|
| **SF Symbols** (`Image(systemName:)`, `Label(..., systemImage:)`) in product surfaces | Forces symmetric HIG metaphor; too little character | **Lucide or Phosphor** (MIT) via `OWIcon` ([OWIcons.md](./OWIcons.md)) |
| **System `.borderedProminent` / accentColor blue** as primary brand actions | User’s macOS accent ≠ OpenWrite accent | `OWButton` primary variant with `DesignTokens.Color.accent` |
| **`.buttonStyle(.bordered)` toolbars** as the main nav metaphor | Capsule chrome dominates calm rail | Plain `Button` + `OWIcon` in custom toolbar regions |
| **Vibrancy / `Material` stacks** in workbench body | Blur fights paper-like editor canvas | Flat `editorCanvas` + `surface` tokens |
| **`ContentUnavailableView` with system symbol** | Bundled SF artwork in empty states | `OWPageHero` `.emptyState` with `OWIcon` |
| **Stock `Picker` / `Menu` labels** with SF leading icons | Inconsistent stroke weight vs open set | `OWIcon` + `Typography.*` labels |
| **Shield / lock SF glyphs** that read as Apple security branding | Wrong brand | Neutral `OWIcon` vault/lock from open set |

**Allowed platform exceptions (narrow):**

- Native **alerts**, **file panels**, and **Settings** scene chrome where AppKit owns control drawing.
- **Standard scrollbars** and **text caret** (do not custom-draw).
- **VoiceOver** and **keyboard** behaviors from macOS; labels must still name actions in OpenWrite copy.
- **Monospaced system font** for code blocks only.

---

## Anytype framework vs aesthetics

| Anti-pattern | Why it fails | Use instead |
|--------------|--------------|-------------|
| **Porting Anytype TS/Electron patterns** (middleware, object IDs, sync) | ASAL + wrong stack; user: framework is “bad” | SwiftUI + NDL + `OWDatabase` in `OpenWrite/` only |
| **Empty Anytype-shaped shell** without Anytype-quality fill | Too much framework, too little aesthetic | Gradient banner, dense rows, filled blocks ([FrontendPriorities.md § 4](./FrontendPriorities.md#4-anytype-aesthetics-without-the-anytype-framework)) |
| **Anytype assets, hex, or copy** | ASAL / trademark risk | Clean-room patterns in [AnytypeUIInspiration.md](./AnytypeUIInspiration.md) |
| **Washed system-blue type icons** in sidebar | Reads as HIG list, not object wells | Saturated icon wells per `ObjectType` |

---

## Layout and proportion

| Anti-pattern | Why it fails | Use instead |
|--------------|--------------|-------------|
| **Inspector ≥ 50% of content width** at default window | AI competes with author ([ProductDirection.md](../ProductDirection.md)) | Inspector collapsed by default; cap at `inspectorMaxWidth` (360pt) |
| **LM Studio block in left rail** above vault list | Operator config in primary nav | Settings (`Cmd+,`) or compact footer strip |
| **Full-screen AI on launch** | Author-first violation | **Bloom intro** then editor; inspector closed |
| **Multi-second splash** blocking edit | Friction vs Anytype Bloom | **0.35–0.45s** wordmark fade ([FrontendPriorities.md § 5](./FrontendPriorities.md#5-bloom-intro)) |
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
| **San Francisco / Inter-only product chrome** | Looks like “just works” Apple app, not a writing desk | **Serif** bundled faces via `DesignTokens.Typography` |
| **Mixed icon sets** (SF + Lucide + emoji in nav) | Uneven visual weight | **One** open family (Lucide *or* Phosphor) + emoji only for page hero icons |
| **Hand-drawn icons that mimic SF grid** | Misses “richer, more open” goal | Import MIT SVGs; slightly asymmetric strokes OK |
| **Arbitrary icon sizes** (14pt, 22pt) | Misaligned baselines | `sidebarRowIconSize` (18), hero (48), toolbar (20) |

---

## Brand

| Anti-pattern | Why it fails | Use instead |
|--------------|--------------|-------------|
| **Treating placeholder “OW box” as shippable brand** | User will replace logo themselves | [BrandAndLogo.md](./BrandAndLogo.md) — engineering does not block on logo |
| **Engineering iteration on logo** during frontend push | Distracts from density/typography/icons | Typographic wordmark on Bloom intro only |

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
| **Importing reference-repo UI code** | License contamination | Port behavior to Swift in `OpenWrite/` only |

---

## Review gate

Before merging UI work, confirm:

- [ ] No `systemName:` / `systemImage:` in `OpenWrite/UI/**` (except documented platform exceptions)
- [ ] Serif typography on hero, rail, and section labels via bundled fonts
- [ ] Icons from **one** MIT open set (Lucide or Phosphor) through `OWIcon`
- [ ] Sidebar uses **custom rail**, not HIG `List` selection
- [ ] Center column **filled** — no vast empty void at default window size
- [ ] Bloom intro ≤ 0.5s if launch flow touched
- [ ] AI sub-panels expose back navigation when depth &gt; 1
- [ ] Column widths respect [ProductDirection.md § Resize rules](./ProductDirection.md#resize-rules)
- [ ] No grouped `Form` in editor or inspector **content** bodies
- [ ] [FrontendPriorities.md § Filled UI checklist](./FrontendPriorities.md#filled-ui-checklist) P0 items considered

---

*See also: [OpenWriteDesignLanguage.md § Anti-patterns](./OpenWriteDesignLanguage.md#anti-patterns)*
