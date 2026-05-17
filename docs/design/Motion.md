# OpenWrite Motion & Animation

**Version:** 1.0  
**Implementation:** `DesignTokens.Motion` + SwiftUI `.animation` / `withAnimation`

Motion supports the **calm** principle: it confirms spatial changes and state transitions without drawing attention to the chrome itself.

---

## Table of contents

1. [Philosophy](#philosophy)
2. [Duration tokens](#duration-tokens)
3. [Easing curves](#easing-curves)
4. [Component animations](#component-animations)
5. [Reduced motion](#reduced-motion)
6. [SwiftUI patterns](#swiftui-patterns)
7. [Anti-patterns](#anti-patterns)

---

## Philosophy

| Do | Don't |
|----|-------|
| Animate layout changes when sidebar/inspector toggles | Bounce every button |
| Fade sheet in/out | Parallax background on editor |
| Short crossfade on vault unlock → workbench | Spinning logo on every save |
| Honor `accessibilityReduceMotion` | Autoplay decorative loops |

OpenWrite is a writing tool; motion budget per user session should stay **under ~2 seconds total** of non-user-initiated animation excluding graph layout.

---

## Duration tokens

| Token | Seconds | Use |
|-------|---------|-----|
| `durationInstant` | 0.08 | Opacity micro-feedback, tooltip |
| `durationFast` | 0.15 | Hover states, tab indicator slide |
| `durationStandard` | 0.22 | Sidebar collapse, inspector toggle |
| `durationSlow` | 0.32 | Sheet present/dismiss |
| `durationEmphasis` | 0.45 | Vault unlock success crossfade only |

### Mapping to perceived speed

- **&lt; 0.1s:** feels instant; use for feedback only
- **0.15–0.25s:** sweet spot for macOS UI
- **&gt; 0.35s:** risks sluggishness; reserve for large surface changes

---

## Easing curves

| Token | SwiftUI | Use |
|-------|---------|-----|
| `easeStandard` | `.easeInOut` | Default layout |
| `easeOut` | `.easeOut` | Entering elements (sheet) |
| `easeIn` | `.easeIn` | Exiting elements |
| `springSnappy` | `spring(response: 0.28, dampingFraction: 0.86)` | Tab bar, optional |
| `springGentle` | `spring(response: 0.38, dampingFraction: 0.92)` | Graph node focus (if motion allowed) |

Avoid high-damping bouncy springs; OpenWrite is not a game UI.

---

## Component animations

### Sidebar show/hide

| Property | Value |
|----------|-------|
| Duration | `durationStandard` |
| Curve | `easeStandard` |
| Property | width or `NavigationSplitView` visibility |
| Reduced motion | Instant visibility toggle, no slide |

### Inspector show/hide

Same as sidebar; collapse inspector before sidebar when window narrows (no animation queue stacking).

### Workbench tab switch

| Property | Value |
|----------|-------|
| Duration | `durationFast` |
| Property | underline offset + content opacity 0.92 → 1 |
| Reduced motion | Instant tab swap |

### Capture sheet

| Phase | Duration | Curve |
|-------|----------|-------|
| Present | `durationSlow` | `easeOut` |
| Dismiss | `durationFast` | `easeIn` |
| Dim scrim | `durationStandard` | linear opacity |

Sheet vertical offset: 8pt → 0 on present (optional; disable when reduced motion).

### Vault unlock → workbench

| Property | Value |
|----------|-------|
| Duration | `durationEmphasis` |
| Effect | crossfade + 4pt vertical offset settle |
| Reduced motion | hard cut |

### Editor

| Action | Motion |
|--------|--------|
| Block focus change | Background fade `durationInstant` |
| New block insert | No slide; optional 4pt fade `durationFast` |
| Delete block | Instant removal (v1); animate height collapse in v2 with reduced-motion guard |

### Graph view

| Action | Duration | Notes |
|--------|----------|-------|
| Pan/zoom | none (direct manipulation) | |
| Node select | `durationFast` scale | Disabled if reduced motion |
| Layout refresh | `durationSlow` fade-in nodes | Prefer instant if &gt; 50 nodes |

### AI streaming

Text appearance: **no per-token animation**; append plain text. Blinking cursor optional at 1 Hz max or static bar.

### Errors

Password field shake: 3 cycles, 4pt horizontal, `durationFast` — **skip** when `accessibilityReduceMotion`.

---

## Reduced motion

### Detection

```swift
@Environment(\.accessibilityReduceMotion) private var reduceMotion

var animation: Animation? {
    reduceMotion ? nil : DesignTokens.Motion.animationStandard
}
```

### Rules

1. If `reduceMotion == true`, use `nil` animation or `Animation.linear(duration: 0)`.
2. Replace slides with **opacity** or instant swaps.
3. Graph physics: static layout only.
4. Never require motion to understand state (e.g. don’t hide unlock success only in animation).

### Testing

- System Settings → Accessibility → Display → **Reduce motion**
- Verify sidebar, sheet, vault, and graph paths

---

## SwiftUI patterns

### Standard toggle

```swift
withAnimation(DesignTokens.Motion.animationStandard) {
    workbenchState.sidebarVisible.toggle()
}
```

### Conditional animation helper

Implement `DesignTokens.Motion.animation(_ reduceMotion: Bool) -> Animation?` in code.

### Transaction for matched geometry (v2)

Use `matchedGeometryEffect` sparingly for tab content; IDs stable per document.

---

## Anti-patterns

1. **`animation(_:value:)` on body text** — causes jank while typing
2. **Long spring on every `Button`** — noisy
3. **Blocking `sleep` for motion** — use completion handlers
4. **Confetti / celebration** — out of brand
5. **Ignoring reduce motion** — accessibility failure

---

## Changelog

| Version | Change |
|---------|--------|
| 1.0 | Initial motion spec |

---

*See also: [Tokens.md § Motion](./Tokens.md#motion-cross-reference) · [Accessibility.md](./Accessibility.md)*
