# OpenWrite — Brand & Logo Guidance

**Version:** 1.0  
**Last updated:** 2026-05-17  
**Audience:** Founders, designers (Figma), engineers shipping `AppIcon.appiconset`  
**Related:** [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) · [Tokens.md](./Tokens.md) · `OpenWrite/Design/DesignTokens.swift`

---

## Positioning

OpenWrite is an **app of apps** for private knowledge work: one native macOS shell that unifies **writing** (NDL editor), **structure** (types, properties), **navigation** (graph, backlinks), **memory** (encrypted vault), and **local AI** (RAG, chat)—without feeling like five products bolted together.

| Reference vibe | What to borrow | What to avoid |
|----------------|----------------|---------------|
| **Notion** | Single clear mark, calm neutrals, wordmark confidence | Busy illustrations, rainbow section colors |
| **Figma** | Geometric simplicity, “tool for makers” clarity | Multi-color logo stacks |
| **AFFiNE** | Block-native metaphor, workspace unity | Pixel-copying their palette or shapes |

**Brand promise in one line:** *Your vault, your blocks, one calm desk.*

Logo and icon work should feel **Notion-simple**: one metaphor, readable at 16px, no fine detail—so the Dock, Finder, and menu bar stay legible beside Apple and third-party productivity apps.

---

## Logo concept directions

Explore **four to five** directions in Figma before committing. Keep each direction to **one primary idea**; kill variants that need a caption to parse.

### 1. Wordmark — “OpenWrite”

Typographic lockup only: custom or licensed geometric sans (e.g. **Inter**, **SF Pro** for macOS parity, or **Geist**-class). Treat **Open** and **Write** as one word with subtle weight shift (Open Regular + Write Medium) or single weight with letterspacing tuned for “OW” rhythm.

```
┌─────────────────────────────────────┐
│                                     │
│     OpenWrite                       │
│     ─────────                       │
│     (single weight, tight tracking) │
│                                     │
└─────────────────────────────────────┘
```

**Best for:** Marketing site, About panel, splash. Pair with a separate app icon (not the full wordmark in the Dock).

### 2. Monogram — “OW”

Two letters as one glyph: shared stem, overlapping bowls, or a single continuous stroke. Works inside a **rounded square** (macOS squircle) or alone on `background`.

```
     ┌──────┐
     │ O╲   │
     │  ╲W  │   ← ligature or stacked, max 2 strokes
     └──────┘
```

**Best for:** App icon, menu bar template (future), favicon. **Default placeholder** in repo uses this direction on `accent` fill.

### 3. Pen + vault

Minimal pen nib or stroke merging with a **closed shape** (vault door arc, lock shackle simplified to one curve). One pen, one enclosure—never a detailed padlock.

```
        ╱
       ╱  ← pen
      ╱
    ┌─────┐
    │     │  ← vault / safe curve
    └─────┘
```

**Best for:** Storytelling “private writing.” Risk: cliché; only proceed if geometry stays **≤4 anchor points** at icon size.

### 4. Unified blocks

Two or three **rounded rectangles** (NDL blocks / app tiles) with one block slightly elevated or accented—signals “app of apps” and block-native editor.

```
    ┌──┐
    │  │┌──┐
    └──│  │
       └──┘
```

**Best for:** Product screenshots, feature marketing. Align corner radius with `DesignTokens.Radius.medium` (6pt at UI scale; scale proportionally in icon).

### 5. Minimal geometric

Single mark: rounded square container + **one** inner element (dot, line, or chevron suggesting “open page”). No gradients in the mark; optional subtle shadow only in marketing lockups.

```
    ┌────────┐
    │   ▭    │   ← one bar or page corner
    └────────┘
```

**Best for:** Maximum Dock legibility; closest to Notion/Figma discipline.

---

## Color recommendations

Tie brand color to **`DesignTokens.Color.accent`** and `Assets.xcassets/AccentColor`—do not introduce a second primary hue in v1.

| Role | Token | Light (sRGB) | Hex (approx.) | Use in logo |
|------|--------|--------------|---------------|-------------|
| Primary brand | `accent` | 0.23, 0.42, 0.88 | `#3A6BE0` | Icon fill, monogram, links in wordmark |
| Primary (dark UI) | `accent` (dark) | 0.35, 0.55, 0.95 | `#598CF2` | Dark-mode icon variant (optional second export) |
| Muted brand | `accentMuted` | accent @ 14% | — | Background tint in marketing only |
| On-accent text | — | white @ 100% | `#FFFFFF` | “OW” on solid accent (placeholder icon) |
| Structure | `textPrimary` / `background` | see [Tokens.md](./Tokens.md#color) | — | Wordmark on light/dark layouts |

**Neutrals for wordmark:** `textPrimary` on `background`—never pure `#000` / `#FFF` in product chrome.

**Do not use** `danger`, `success`, or `warning` in the logo mark (semantic colors only in UI).

### Contrast checks

| Pair | Minimum |
|------|---------|
| White monogram on `accent` fill | ≥ 4.5:1 (WCAG AA text) |
| `accent` mark on `background` | ≥ 3:1 for non-text logo (AA large / graphical) |

---

## “Notion-simple” rules

1. **Single metaphor** per lockup (monogram *or* blocks *or* pen-vault—not all three).
2. **Works at 16×16** (menu bar / Finder small): test the icon at 16px with macOS “Reduce transparency” on.
3. **No fine detail**: no thin hairlines &lt; 2px at 128px artboard; no gradients inside the Dock icon.
4. **No text in the app icon** except optional monogram letters **designed as shapes** (not live 12pt type).
5. **Squircle-safe**: keep critical shape inside **~80%** of the canvas (see safe zone below).
6. **Flat or one level**: at most one subtle inner highlight; save depth for marketing renders.
7. **Consistent with UI**: same accent as wikilinks and selection—user recognizes the app in the editor.

---

## App icon size checklist (macOS)

Export PNG (sRGB), no transparency for App Store–style icons (macOS allows transparency in dev; prefer opaque for consistency).

| Point size | @1x (px) | @2x (px) | Filename (suggested) |
|----------|----------|----------|----------------------|
| 16 | 16 | 32 | `icon_16x16.png`, `icon_16x16@2x.png` |
| 32 | 32 | 64 | `icon_32x32.png`, `icon_32x32@2x.png` |
| 128 | 128 | 256 | `icon_128x128.png`, `icon_128x128@2x.png` |
| 256 | 256 | 512 | `icon_256x256.png`, `icon_256x256@2x.png` |
| 512 | 512 | 1024 | `icon_512x512.png`, `icon_512x512@2x.png` |

**Marketing / press (optional, not in Xcode set):**

| Use | Size |
|-----|------|
| Social / README | 512, 1024 |
| App Store–style hero | 1024, 2048 |
| Email signature | 64, 128 |

**Repo placeholder:** `AppIcon.appiconset` includes a generated **OW monogram** on accent (`#3A6BE0`). Replace all sizes together when final art is ready—see `Contents.json` for the full list.

---

## Figma handoff

### File structure

| Page | Contents |
|------|----------|
| `Logo / Concepts` | Five artboards, one per direction |
| `Logo / Chosen` | Master vector + light/dark |
| `App Icon` | macOS export frames |
| `Marketing` | Wordmark + safe area guides |

### Artboard sizes (design at 1×, export @1x and @2x)

| Frame | Size (px) | Notes |
|-------|-----------|--------|
| App icon master | **1024 × 1024** | Design here; downscale for all slots |
| App icon preview | 512 × 512 | Quick Dock preview |
| Monogram only | 256 × 256 | Menu bar / future status item |
| Wordmark | 1200 × 400 | Horizontal lockup |
| Favicon (web docs) | 32 × 32 | Optional |

### Safe zone

- **macOS squircle** masks corners; keep logo mass inside **center 820 × 820** on a 1024 canvas (**~10% inset** each side).
- For monogram **OW**, cap letter height at **~62%** of canvas height.
- Align to **pixel grid** at 16, 32, 128 exports (snap strokes to whole pixels at each export size).

### Export settings

| Setting | Value |
|---------|--------|
| Format | PNG |
| Color profile | sRGB |
| Scales | @1x and @2x per slot (or export 1024 master and use `sips` / Xcode asset catalog) |
| Transparency | Off for final App Icon (opaque background) |
| Naming | Match `icon_<size>.png` / `icon_<size>@2x.png` in `AppIcon.appiconset` |

### Handoff to engineering

1. Export full **`.appiconset`** or single **1024** PNG + `Contents.json` filenames.
2. Drop into `OpenWrite/OpenWrite/Assets.xcassets/AppIcon.appiconset/`.
3. Verify `AccentColor.colorset` still matches `DesignTokens.Color.accent`.
4. Run `xcodebuild -scheme OpenWrite build` (or Xcode **Product → Build**).

---

## Decision log (fill in)

| Date | Decision | Owner |
|------|----------|--------|
| | Chosen direction (1–5) | |
| | Wordmark typeface | |
| | Dark-mode separate icon? (Y/N) | |

---

## Placeholder icon (repository)

Until final brand art ships, the asset catalog contains a **developer placeholder**:

- Solid fill: `DesignTokens.Color.accent` light appearance (`#3A6BE0`)
- **OW** monogram in white, centered, bold system face
- All macOS slots generated from a 1024×1024 master via `scripts/generate_app_icon_placeholder.sh`

**Replace before public release**—placeholder is not a trademark-ready brand.

---

## Quick links

- Design index: [README.md](./README.md)
- UI tokens: [Tokens.md](./Tokens.md)
- Product tone: [../ProductPhilosophy.md](../ProductPhilosophy.md)
