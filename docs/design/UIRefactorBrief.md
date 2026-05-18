# UI Refactor Brief (canonical)

**Version:** 1.0  
**Last updated:** 2026-05-17  
**Status:** **Refactor Phase 0** — handoff to implementation agents  
**Audience:** SwiftUI engineers, design reviewers, autonomous agents  

**Related:** [CurrentUIAudit.md](./CurrentUIAudit.md) · [FrontendPriorities.md](./FrontendPriorities.md) · [AnytypeUIInspiration.md](./AnytypeUIInspiration.md) · [../HANDOFF.md](../HANDOFF.md) · [../AGENT_PROMPT_UI_REFACTOR.md](../AGENT_PROMPT_UI_REFACTOR.md)

---

## Mission

Rebuild OpenWrite’s **perceived quality** to match **Anytype aesthetics** (filled surfaces, cover gallery, draggable page icon, dense object rows, submenu chrome) while staying **native SwiftUI on macOS** — explicitly **without** Anytype’s Electron/TypeScript framework, middleware, or assets.

Downloads depend on this pass more than new backend epics. Assume vault, NDL, and local RAG are viable; fix shell, typography registration, block layout, and header interactions first.

---

## Current failures (user feedback + screenshot)

Evidence: [CurrentUIAudit.md](./CurrentUIAudit.md), captures under [docs/assets/ui-refactor/](../assets/ui-refactor/).

| Failure | Symptom | Likely cause | User impact |
|---------|---------|--------------|-------------|
| **Font fallback banner** | Yellow/warning strip: “Source Serif 4 did not load…” | `UIAppFonts` in `Info.plist` is iOS-oriented; macOS may not register bundle fonts before `NSFont(name:)` probe; PostScript name mismatch | Product reads broken / unfinished; serif intent lost |
| **Clipped block text** | Paragraph and list text truncates inside rounded block cards | `OWPreviewBlockRow` / editor rows: tight `lineLimit`, missing `fixedSize(horizontal:vertical:)`, or card height not growing with `axis: .vertical` fields | Writing surface feels broken |
| **Emoji panel placement** | Popover anchors poorly vs page icon; overlaps banner or clips at window edge | `popover(arrowEdge: .bottom)` on icon inside `ZStack` with drag offset; no flip/constrain | Page icon edit feels amateur vs Anytype |
| **Header chrome** | Toolbar chips, title field, and banner compete; metadata not in submenu | `OWPageHeaderEditor` stacks toolbar above title; cover/icon/title hierarchy inverted vs reference | “Anytype-shaped” but not Anytype-quality |
| **Hollow center** (secondary) | Large white void under type cards on welcome | Empty-state IA: type picker consumes column without body fill | Screenshot reads “unfinished” |
| **Policy drift** (docs vs code) | [FrontendPriorities.md](./FrontendPriorities.md) still lists Lucide/Phosphor | Implementation moved to **Unicode-only** ([OWIcons.md](./OWIcons.md)) | Agents ship wrong icon work |

---

## Target experience (Anytype aesthetics, native stack)

| Area | Target | Not in scope |
|------|--------|--------------|
| **Shell** | Gray rail + elevated white editor card; editor ≥ 55% width; AI strip collapsed by default | Electron, Anytype sync, ASAL code |
| **Page header** | Cover gradient gallery; **movable** emoji/icon on banner overlap; title at document scale; relations in chip row or submenu | Pixel-perfect Anytype hex/fonts |
| **Filled blocks** | Every NDL block in `OWRoundedRect` with correct line height and growth | Raw `TextEditor` as only surface |
| **Navigation** | `OWNavigationRail`: OBJECTS / DATABASES / VAULT serif caps; pill selection; 36pt rows | `List` + system selection blue |
| **Empty DB / types** | **+ New row** / **+ New Object** CTA under toolbar | Centered void + paragraph only |
| **Icons** | **Unicode only** via `OWUnicodeIconView` | SF Symbols, Lucide SVGs in product UI |
| **Typography** | Bundled **Source Serif 4** on all chrome + editor; banner hidden in release builds | Inter/SF-only product chrome |

Study patterns in [AnytypeUIInspiration.md](./AnytypeUIInspiration.md); map to [OWComponents.md](./OWComponents.md) primitives.

---

## Reference images (`docs/assets/`)

| ID | Path | Use |
|----|------|-----|
| OW-current | [../assets/ui-refactor/openwrite-current.png](../assets/ui-refactor/openwrite-current.png) | Regression baseline (banner, blocks, emoji, header) |
| Anytype-about | [../assets/ui-refactor/anytype-about-page.png](../assets/ui-refactor/anytype-about-page.png) | Cover + icon overlap + metadata chips |
| Anytype-types | [../assets/ui-refactor/anytype-object-types.png](../assets/ui-refactor/anytype-object-types.png) | Dense sidebar + empty-state CTA |
| Anytype-graph | [../assets/ui-refactor/anytype-graph.png](../assets/ui-refactor/anytype-graph.png) | Rail modules + graph entry |
| Reor | [../assets/ui-refactor/reor-editor-chat.png](../assets/ui-refactor/reor-editor-chat.png) | AI column width cap |
| massCode | [../assets/ui-refactor/masscode-four-column.png](../assets/ui-refactor/masscode-four-column.png) | Database four-column lens |

If PNGs are missing locally, copy per [../assets/ui-refactor/README.md](../assets/ui-refactor/README.md). Session copies may also exist under `.cursor/projects/Users-erichspringer-Downloads-OpenWrite/assets/` (not versioned).

Also linked from [../ProductDirection.md](../ProductDirection.md#reference-captures-user-provided-2026-05-17).

---

## Component rewrite order

Execute in order; do not start hero polish before fonts and tokens are trustworthy.

| Phase | Component / file | Outcome |
|-------|------------------|---------|
| **0** | Xcode target + `Resources/Fonts/` + `Info.plist` | Source Serif 4 loads on macOS; remove or gate fallback banner in Release |
| **0** | `OWTypography.swift`, `AppDelegate` font verify | `isBundledSerifAvailable == true` in Debug and Release |
| **1** | `DesignTokens.swift`, `OWRoundedRect.swift` | Semantic surfaces stable for filled UI |
| **2** | `OWNavigationRail.swift`, `OWSidebarRow.swift`, `OWSidebarSection.swift` | Rail density, pills, unicode wells — no system `List` |
| **3** | `OWPageBanner.swift`, `OWCoverStylePickerSheet` (cover gallery) | Gradient strip + picker; Anytype cover behavior clean-room |
| **4** | `OWPageHeaderEditor.swift` | Icon drag, emoji popover placement, submenu for page options; title below icon overlap |
| **5** | `OWPreviewBlockRow.swift`, `OWBlockEditorView.swift` | Unclipped multi-line blocks; consistent vertical rhythm |
| **6** | `EditorView.swift` | Wire header + block editor; welcome template body (no void) |
| **7** | `AnytypeShellView.swift`, `CenterWorkbenchTab` | Proportions, card padding, AI strip default off |
| **8** | `DatabaseTableView.swift`, `DatabaseListView.swift` | + New row empty states |
| **9** | `GraphView.swift` | Card nodes + entry from rail (already partial — align chrome) |
| **10** | `AIAssistStripView.swift`, `ChatPanelView.swift` | Reor-narrow assist; LM Studio only in Settings |
| **11** | `LaunchIntroView.swift` | Bloom ≤ 0.5s; serif wordmark when fonts OK |

Update [CurrentUIAudit.md](./CurrentUIAudit.md) rows as each phase lands.

---

## Typography: Source Serif bundling (Xcode)

**Requirement:** No user-visible fallback banner in shipping builds; all `DesignTokens.Typography` / `OWTypography` paths resolve to bundled faces.

| Step | Action |
|------|--------|
| 1 | Confirm `SourceSerif4-{Regular,Semibold,Bold}.ttf` in **Copy Bundle Resources** (`OpenWrite.xcodeproj`) |
| 2 | macOS registration: add `ATSApplicationFontsPath` = `Fonts` (or register via `CTFontManagerRegisterFontsForURL` at launch) — **`UIAppFonts` alone is insufficient on macOS** |
| 3 | Verify PostScript names match `OWTypography.Family` (`SourceSerif4-Regular`, etc.) via Font Book |
| 4 | Call `OWTypography.verifyBundledFontsAtLaunch()` after registration in `AppDelegate` |
| 5 | Gate `OWTypographyFontWarningBanner` to **Debug** only, or remove when `isBundledSerifAvailable` |

Canon: [Typography.md](./Typography.md).

---

## Icons: Unicode only

**Policy (refactor):** Product UI uses **`OWUnicodeIcon` / `OWUnicodeIconView` only**. No `Image(systemName:)`, no Lucide/Phosphor SVGs, no new `OWIconView` call sites.

| Do | Don't |
|----|--------|
| `OWUnicodeIconView(icon: .graph, size: 16)` | `Image(systemName:)` |
| Page emoji via `OWPageHeaderEditor` / banner chip | Unicode in nav rail (except page icon) |
| Extend `OWUnicodeIcon` enum for new semantics | Revive deprecated `OWIcon` paths in features |

Canon: [OWIcons.md](./OWIcons.md). Align [FrontendPriorities.md](./FrontendPriorities.md) §3 with this policy.

---

## Acceptance (Phase 0 done)

- [x] No font warning banner in Release build at 1200×800
- [x] Block paragraphs show full text without clipping in preview and edit
- [x] Emoji picker opens adjacent to page icon without overlapping title field
- [x] Page header matches reference hierarchy: cover → overlapping icon → title → chips/submenu
- [x] P0 checklist in [FrontendPriorities.md](./FrontendPriorities.md) updated (failed → fixed)
- [x] [CurrentUIAudit.md](./CurrentUIAudit.md) reflects new status

---

## Out of scope for this refactor

- Logo final art ([BrandAndLogo.md](./BrandAndLogo.md))
- Real vault crypto, full RAG streaming, force-directed graph physics v2
- Anytype framework port or cloud sync
- In-app browser (OpenWrite is a writer; use system browser for web pages)

---

## Implementation reality (2026-05-17 cleanup)

Phase 0 UI fixes are in Swift sources on `main` (see recent commits `04bffeb`–`3e5849e` plus working-tree polish). Agents should treat this table as ground truth over older “inspector column” docs.

| Topic | Code |
|-------|------|
| **Shell layout** | `AnytypeShellView` — rail optional; center `OWRoundedRect.editorPanel`; trailing `AIAssistStripView` when `WorkbenchState.aiAssistExpanded`. |
| **Titlebar** | `OWWindowChrome` + `OWSolidTitlebarAccessory` — opaque shell chrome behind traffic lights; `AppDelegate` re-applies on resize/focus/theme. |
| **Editor width** | `View.openWriteEditorContentWidth()` — centered max ~880pt; banner full-bleed; blocks/toolbars share `openWriteEditorLeadingInset()`. |
| **Chat composer** | `ChatPanelView.composerActionBoard` — 2×2 toggles (Notes/Web, Attach/Send); field min height = `DesignTokens.Layout.composerBoardHeight`. |
| **Themed scroll** | `OpenWriteThemedScrollView` — `scrollToBottomOnTokenChange: true` for chat; `scrollToken` remeasure for editor (no spurious scroll-to-bottom). |
| **Graph inline** | `OWRoundedRect` `.editorPanel` uses `maxHeight: .infinity`; `GraphView` empty overlay separated from node layer. |
| **Create page sheet** | `ContentView.newPageSheet` + `openWriteSheetPresentationChrome()` (not system white). |
| **Cover preset** | `CoverStyle.solarizedHeader` for Solarized Warm theme. |
| **Block toolbar** | `OWBlockFormattingToolbar` — B/I/U/S, serif/sans + size dropdowns, Preview toggle; no Insert image button (paste/drag only). |

*Update this brief when Phase 0 completes or reference captures change.*
