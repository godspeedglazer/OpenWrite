# Current UI audit (brutal)

**Version:** 1.0  
**Last updated:** 2026-05-17  
**Build context:** Debug sweep 2026-05-17 ([BUGFIXES.md](../../BUGFIXES.md))  
**Refactor spec:** [UIRefactorBrief.md](./UIRefactorBrief.md)

Status legend: **Fail** = blocks download narrative · **Partial** = shipped but wrong · **Pass** = acceptable for Phase 0 · **N/A** = not attempted

| Area | Status | Fix |
|------|--------|-----|
| **Source Serif bundling** | **Pass** | `ATSApplicationFontsPath` + `CTFontManagerRegisterFontsForURL`; folder copy in bundle |
| **Font fallback banner** | **Pass** | `OWTypography.showsBundledSerifWarningInUI` — Debug only |
| **Serif on hero / rail / labels** | **Pass** | Source Serif 4 via `OWTypography` / `DesignTokens.Typography` |
| **Unicode icons (no SF Symbols)** | **Pass** | Keep `OWUnicodeIconView`; grep guard in CI |
| **Lucide/Phosphor (docs said P0)** | **N/A** | Policy reversed — update docs only; do not import SVGs |
| **OWNavigationRail vs HIG List** | **Partial** | 36pt rows; vault list uncapped vs Anytype reference density |
| **Bloom intro ≤ 0.5s** | **Pass** | ~0.4s sequence; no theme `.id` replay on `LaunchRootView` |
| **Editor column ≥ 55% width** | **Pass** | `editorMinWidthFraction` (0.55) when assist strip open |
| **Inspector collapsed default** | **Pass** | `aiAssistExpanded` defaults false; bottom bar to expand |
| **LM Studio in rail** | **Pass** | Ingestion card only when active/failed; AI dot + Settings for config |
| **OWPageHero / banner / cover** | **Pass** | Banner tap + `OWCoverStylePickerSheet` gradient gallery |
| **Movable page icon** | **Pass** | Drag with bounded offsets in `OWPageHeaderEditor` |
| **Emoji picker placement** | **Pass** | Popover anchored to page icon chip (`attachmentAnchor: .rect(.bounds)`) |
| **Header chrome / submenus** | **Pass** | Title-first; page options in `Menu` (cover, description, icon, reset) |
| **Block preview fill** | **Pass** | Filled cards on headings + body block kinds |
| **Block text clipping** | **Pass** | `fixedSize(vertical:)` on preview/edit rows; block editor host intrinsic sizing |
| **Welcome / empty editor void** | **Pass** | Empty editor preview blocks + type-picker starter CTA |
| **Database empty CTA** | **Pass** | **+ New row** in `DatabaseTableView` toolbar when schema exists |
| **Graph view** | **Pass** | Empty state no longer overlaps node cards when vault has no wikilinks |
| **AI assist strip** | **Partial** | Bottom bar + expand; width rules need Reor reference enforcement |
| **Vault chat dominance** | **Partial** | Chat in strip not full inspector — still feels heavy in captures |
| **Theme switch without state tear** | **Pass** | Per BUGFIXES — retain |
| **Mixed icon sets in nav** | **Pass** | Unicode-only in product UI |
| **Placeholder logo** | **Pass** | User-deferred per [BrandAndLogo.md](./BrandAndLogo.md) |
| **Accessibility / VO on unicode** | **Partial** | Labels on `OWUnicodeIcon`; audit hero emoji button |
| **Docs vs implementation** | **Pass** | [FrontendPriorities.md](./FrontendPriorities.md) aligned to Unicode-only + Phase 0 status |

---

## Screenshot-driven priorities

From [docs/assets/ui-refactor/openwrite-current.png](../assets/ui-refactor/openwrite-current.png) (when present):

1. Font banner — **P0**
2. Clipped blocks — **P0**
3. Emoji popover — **P0**
4. Header toolbar order — **P0**
5. Center column fill — **P1**

---

*Re-run this table after each refactor phase in [UIRefactorBrief.md](./UIRefactorBrief.md).*
