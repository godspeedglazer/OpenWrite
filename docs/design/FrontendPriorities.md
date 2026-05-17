# OpenWrite Frontend Priorities

**Version:** 1.1  
**Last updated:** 2026-05-17  
**Audience:** Design, engineering, agents  
**Status:** **P0 largely pass** — Refactor Phase 0 complete; P1 density/graph polish remains. Canonical spec: [UIRefactorBrief.md](./UIRefactorBrief.md) · audit: [CurrentUIAudit.md](./CurrentUIAudit.md) · handoff: [../HANDOFF.md](../HANDOFF.md).

**Related:** [../ProductDirection.md](../ProductDirection.md) · [ProductDirection.md](./ProductDirection.md) · [AntiPatterns.md](./AntiPatterns.md) · [Typography.md](./Typography.md) · [OWIcons.md](./OWIcons.md) · [AnytypeUIInspiration.md](./AnytypeUIInspiration.md) · [Motion.md](./Motion.md) · [BrandAndLogo.md](./BrandAndLogo.md) · [UIRefactorBrief.md](./UIRefactorBrief.md)

---

## Why frontend is first

Users decide whether OpenWrite “just works and looks pretty” in the first seconds: launch intro, sidebar density, type on the page, icon character, and whether the center column feels **filled** or **empty**. Competitive parity on vault, NDL, and local AI does not matter if the workbench reads as an unfinished Apple utility or a hollow Anytype clone.

**Rule:** No new backend epics block UI passes until the [Filled UI checklist](#filled-ui-checklist) P0 rows are green in a release build.

---

## 1. Abandon HIG ordering (not just symbols)

**What we reject:** Treating Apple Human Interface Guidelines as the **information architecture** for OpenWrite — `NavigationSplitView` + stock `List` sidebar + grouped `Form` in the editor column + system accent blue + SF Symbols as the “native” face.

**What we keep from macOS:** Sandbox, Keychain, menus, shortcuts, standard alerts/file panels, VoiceOver hooks, split-view geometry where it does not dictate chrome.

| HIG habit | OpenWrite replacement |
|-----------|------------------------|
| Sidebar = system `List` with selection tint | **`OWNavigationRail`** — fixed width, custom background, pill selection, no system blue row |
| Section order “Settings-like” | **OBJECTS → DATABASES → VAULT** (product IA, not Settings.app) |
| Inspector as equal column | **Collapsed by default**; writing column ≥ 55% width |
| Empty center = `ContentUnavailableView` + SF glyph | **`OWPageHero`** + dense CTAs (“+ New row”, type sheet) |
| Search = stock `NSSearchField` chrome | Custom-styled search in rail (flat field, serif caption, `OWIcon` leading) |

**Ordering principle:** Author lands on **editor canvas** after intro; AI and operator config are secondary surfaces ([EditorAndAIPanel.md](./EditorAndAIPanel.md)). Do not mirror Apple’s sidebar section order or Settings density.

Implementation hub: `AnytypeShellView.swift`, `OWNavigationRail` (when landed). Philosophy detail: [SidebarPhilosophy.md](./SidebarPhilosophy.md) (when present).

---

## 2. Serif typography

**Intent:** Punchy, editorial serif for display and section labels — user reference **ITC Serifa** (“makes sense” for a writing product). SF / neutral sans-only chrome reads as “another Mac utility” and contributed to “weird fonts” feedback.

| Role | Target face | Notes |
|------|-------------|--------|
| **Display** | Serifa-class serif (bundled **Source Serif 4** or **Literata**, OFL) | Page titles, wordmark on intro |
| **UI chrome** | Same family, Medium/SemiBold at small sizes | Sidebar rows, section headers |
| **Section labels** | Small caps serif — `OBJECTS`, `DATABASES`, `VAULT` | Not SF `.caption` system style |
| **Body / editor** | Serif regular or paired sans — document choice in [Typography.md](./Typography.md) | Long-form readability |
| **Code** | System monospaced | Only exception to serif chrome |

**Do not** ship Inter-only or default `Font.body` in product surfaces. Register fonts in `UIAppFonts`; route through `DesignTokens.Typography` / `OWTypography`.

---

## 3. Open icons (Unicode only — refactor policy)

**Intent:** Distinct glyphs without SF Symbols or Electron-era asset pipelines. **Shipped policy (2026-05-17):** **`OWUnicodeIcon` / `OWUnicodeIconView` only** — see [OWIcons.md](./OWIcons.md).

| Do | Don't |
|----|--------|
| `OWUnicodeIconView` for nav, types, AI, graph | `Image(systemName:)` / Lucide / Phosphor in product UI |
| Page **emoji** on banner / hero only | Emoji in sidebar nav wells |

**Deprecated:** `OWIcon` / `OWIconView` path shapes — reference only, no new call sites. Lucide/Phosphor were removed from P0; do not reintroduce without explicit product decision.

---

## 4. Anytype aesthetics without the Anytype framework

**Clarification (user feedback):** Current shell is **too much like Anytype in framework** (split regions, object-type chrome, empty columns) and **too little like Anytype in aesthetics** (filled blocks, gradient headers, dense lists, coherent object rows).

| Copy | Do not copy |
|------|-------------|
| Calm gray rail + white editor card | Anytype TS/Electron stack, middleware, ASAL code |
| Pill selection, 36pt object rows, page hero + banner | Exact hex, fonts, icons, marketing strings |
| Playground-style **gradient strip** behind page icon | “Generate in seconds” cloud features |
| **+ New row** / **+ New Object** CTAs in empty DB views | Full relation graph / sync mesh |
| Saturated icon wells on types | Washed system-blue list icons |

**Study:** [AnytypeUIInspiration.md](./AnytypeUIInspiration.md), user captures in [ProductDirection.md § Reference captures](../ProductDirection.md#reference-captures-user-provided-2026-05-17).

**Ship in SwiftUI:** `OWPageBanner`, `OWRoundedRect`, dense `OWSidebarRow`, reduced dead margins, vertical fill — all clean-room.

---

## 5. Bloom intro

**Reference:** Anytype “Bloom” launch — **&lt; 0.5s**, smooth, introduces the app then yields to the workbench (clean-room motion only).

| Property | Target |
|----------|--------|
| Duration | **0.35–0.45s** total (wordmark fade) |
| Surface | Full-window overlay; theme background from `ThemeManager` |
| Content | “OpenWrite” wordmark in **display serif** — not system title |
| Frequency | Once per app version or `hasSeenIntro` (`@AppStorage`) |
| After | Crossfade to main shell — no blocking spinner |

Spec: [Motion.md](./Motion.md) (`durationEmphasis` is upper bound for unlock only; intro stays faster). Implementation: `LaunchIntroView.swift`.

---

## 6. Filled UI checklist

Use before calling a build “download-ready.” Check in Debug at default window **1200×800**. Status from user feedback + [CurrentUIAudit.md](./CurrentUIAudit.md) (2026-05-17).

### P0 — Must feel true in screenshots

- [x] **Launch:** Bloom intro ≤ 0.5s, then editor-forward shell — **pass** (~0.4s; once per app version)
- [ ] **Sidebar:** Custom rail — no system `List` selection blue; section headers in serif small caps — **partial** (`OWNavigationRail` landed; vault list caps vs Anytype reference)
- [x] **Typography:** Serif on hero, sidebar, and section labels — **pass** (macOS bundle registration; warning banner Debug-only)
- [ ] **Icons:** Unicode only via `OWUnicodeIcon` — zero `systemName:` in `OpenWrite/UI/**` — **pass**
- [x] **Editor:** `OWPageHero` + gradient banner + cover gallery; center column widest — **pass** (banner tap → cover sheet; editor ≥55% with assist open)
- [x] **Page header:** Movable icon, emoji picker placement, submenu chrome — **pass** (icon-anchored popover; options menu)
- [x] **Blocks:** Filled preview rows without clipped text — **pass**
- [x] **Inspector / AI:** Collapsed by default; ≤ 320pt when open — **pass**
- [x] **Empty database:** “+ New row” under toolbar — **pass**
- [x] **Dead space:** No full-height empty column — **pass** (empty editor + type-picker hints)
- [x] **LM Studio:** Not a giant block in left rail — **pass** (Settings for config; ingestion card when active only)

### P1 — Anytype-density parity

- [ ] Object/type rows: **36pt** height, saturated icon well, pill selection
- [ ] Property strips as `OWRoundedRect` cards, not grouped `Form` in editor column
- [ ] Block preview or styled sections with backgrounds (not raw `TextEditor` floating in gray)
- [ ] Graph entry in rail with custom empty state (not WebView port)

### P2 — Polish

- [ ] AI panel back stack (`OWAIPanelHeader`) on depth &gt; 0
- [ ] Theme palette applies to intro + rail + canvas consistently
- [ ] Reduce motion path verified

---

## 7. Logo deferred to user

**Decision:** Final brand mark is **out of engineering scope** for the frontend push. Placeholder “OW in a box” is acceptable for dev builds only.

| Owner | Action |
|-------|--------|
| **User / design** | Figma directions in [BrandAndLogo.md](./BrandAndLogo.md); replace `AppIcon.appiconset` when ready |
| **Engineering** | Do not block UI checklist on logo; do not iterate on placeholder except contrast/safe-zone fixes |

User quote: *“I'll work on the logo. Whatever. Screw it.”* — treat wordmark on Bloom intro as **typographic**, not final brand.

---

## Refactor Phase 0 (active)

**Canonical spec:** [UIRefactorBrief.md](./UIRefactorBrief.md) · **Audit:** [CurrentUIAudit.md](./CurrentUIAudit.md) · **Agent entry:** [../AGENT_PROMPT_UI_REFACTOR.md](../AGENT_PROMPT_UI_REFACTOR.md)

| Step | Focus | Exit criteria |
|------|--------|---------------|
| 0a | macOS Source Serif bundling | No font warning banner in Release; `isBundledSerifAvailable` true |
| 0b | Block layout | `OWPreviewBlockRow` / editor: no clipped multi-line text |
| 0c | Page header | Emoji popover placement; cover gallery; icon drag; submenu chrome |
| 0d | Welcome fill | Template body or CTA row — no type-card void |
| 0e | Checklist burn-down | P0 rows above move from failed/partial → pass |

Reference captures: [../assets/ui-refactor/](../assets/ui-refactor/).

---

## Sequencing (recommended)

| Week | Focus |
|------|--------|
| 0 | **Refactor Phase 0** — fonts, blocks, page header, welcome fill ([UIRefactorBrief.md](./UIRefactorBrief.md)) |
| 1 | HIG ordering exit: rail density, inspector default, serif verified on all surfaces |
| 2 | Anytype aesthetic density: banner, filled empty states, row wells |
| 3 | Bloom intro + checklist burn-down + user logo drop-in when provided |

---

## Cross-links

| Topic | Document |
|-------|----------|
| Writing-first layout | [../ProductDirection.md § 2](../ProductDirection.md#2-writing-first-ai-second-reor-dual-generator) |
| Forbidden patterns | [AntiPatterns.md](./AntiPatterns.md) |
| Resize / AI back | [ProductDirection.md](./ProductDirection.md) |
| Icon policy | [OWIcons.md](./OWIcons.md) |
| Type scale | [Typography.md](./Typography.md) |

*Update when P0 checklist items flip to done or when icon/font families are finalized.*
