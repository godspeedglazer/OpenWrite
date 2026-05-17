# OpenWrite Accessibility

**Version:** 1.0  
**Target:** macOS 14+, VoiceOver, keyboard-only, increased contrast, reduced motion

Accessibility is a shipping requirement, not a polish pass. OpenWrite’s audience includes writers who rely on keyboard navigation, screen readers, and high-contrast system settings.

---

## Table of contents

1. [Commitments](#commitments)
2. [VoiceOver](#voiceover)
3. [Contrast & color](#contrast--color)
4. [Keyboard](#keyboard)
5. [Focus & navigation](#focus--navigation)
6. [Dynamic Type & text](#dynamic-type--text)
7. [Motion & vestibular](#motion--vestibular)
8. [Testing checklist](#testing-checklist)

---

## Commitments

| Area | Standard |
|------|----------|
| **WCAG 2.2** | Level AA for text and controls in default themes |
| **HIG Accessibility** | Follow Apple’s macOS accessibility guidance |
| **Keyboard** | All primary flows operable without pointer |
| **VoiceOver** | Meaningful labels on all actionable UI |
| **Reduced motion** | [Motion.md](./Motion.md) compliance |

---

## VoiceOver

### Labels

Every interactive control needs an explicit label. Icon-only toolbar buttons use:

```swift
Button { } label: { Image(systemName: "sidebar.left") }
    .accessibilityLabel("Toggle sidebar")
```

Avoid redundant “button” in label (VoiceOver adds role).

### Hints

Use hints sparingly when action is non-obvious:

```swift
.accessibilityHint("Opens quick capture sheet")
```

### Traits

| UI | Traits |
|----|--------|
| Section title | `.isHeader` |
| Selected tab | `.isSelected` |
| Disabled control | `.isStatic` or remove from loop |
| Secure field | default secure field behavior |

### Grouping

- **Sidebar:** `AccessibilityElement(children: .contain)` on `List`
- **Inspector citation list:** combine related chips or announce count: “3 citations”
- **Graph:** each node is an element; edges decorative (`accessibilityHidden(true)`)

### Announcements

Post notifications for async outcomes:

```swift
AccessibilityNotification.Announcement("Vault unlocked").post()
```

Use for: unlock success, capture saved, indexing complete, LM Studio unreachable (optional).

### Rotor & tables

When outline or backlinks use `Table`/`Grid`, expose column headers. Prefer `List` for simpler navigation.

### Component-specific labels

| Component | Label pattern |
|-----------|---------------|
| Sidebar note row | “{title}, note” |
| Graph node | “{title}, {n} links, button” |
| AI citation | “Open {title}, block {id}” |
| Vault unlock | “Vault password, secure text field” |
| Capture field | “Quick capture text” |

Full component context: [Components.md](./Components.md).

---

## Contrast & color

### Minimum ratios (AA)

| Pair | Ratio target |
|------|--------------|
| `textPrimary` on `background` | ≥ 4.5:1 (body), ≥ 3:1 (large title) |
| `textSecondary` on `background` | ≥ 4.5:1 for captions users must read |
| `accent` on `background` | ≥ 4.5:1 for link text |
| `danger` on `background` | ≥ 4.5:1 for error text |

### Increased Contrast

When macOS **Increase Contrast** is on:

- Prefer system `Color.primary` / `secondary` where semantic tokens might fail audit
- Bump `separator` opacity
- Avoid `textTertiary` for essential labels

Future: `DesignTokens` may read `@Environment(\.colorSchemeContrast)` to adjust programmatic colors.

### Color alone

Never encode state **only** with color:

| State | Non-color cue |
|-------|----------------|
| LM unreachable | Icon + text “Unreachable” |
| Destructive | “Delete” label + confirm alert |
| Selected tab | Underline + bold |
| Wikilink | Underline or icon optional |

### Dark mode

Verify both appearances in Accessibility Inspector (Xcode → Open Developer Tool).

---

## Keyboard

### Global commands (target)

| Shortcut | Action |
|----------|--------|
| `Cmd+N` | New note |
| `Cmd+Shift+N` | Quick capture |
| `Cmd+O` | Open vault |
| `Cmd+S` | Save (when explicit save exists) |
| `Cmd+F` | Find in note |
| `Cmd+Shift+F` | Search vault |
| `Cmd+K` | Insert wikilink |
| `Cmd+,\`` | Toggle split (inspector) |
| `Cmd+Ctrl+S` | Toggle sidebar |
| `Cmd+1`–`Cmd+5` | Sidebar sections |
| `Cmd+W` | Close tab |
| `Cmd+Tab` | System — don’t override |

Register in `OpenWriteApp` with `.commands` modifier.

### Focus order

Logical order: sidebar → main toolbar → editor → inspector. Use `@FocusState` for capture sheet trap:

1. Capture field on open
2. Tab to destination picker
3. Tab to Save / Cancel

### Full keyboard access

Enable **Settings → Keyboard → Keyboard navigation → Full Keyboard Access** during QA; all controls must show focus ring (system or `accent` 2pt outline).

---

## Focus & navigation

### Visible focus

Do not set `focusable(false)` on editor unless read-only. Custom blocks use:

```swift
.focusable()
.focusEffectDisabled(false) // macOS 14+
```

### Modal sheets

Capture and alerts trap focus until dismissed. `Esc` dismisses capture.

### Split view

When inspector collapses, move focus to main column; announce via accessibility notification if focus target lost.

---

## Dynamic Type & text

### Semantic fonts

Use `DesignTokens.Typography` built on `Font.body`, etc., so user text size preferences propagate.

### Limits

Graph minimap and dense tables may clip with `@ScaledMetric(relativeTo: .caption)` max 1.3×; provide scroll if content overflows.

### Editor

Block editor should respect user font size for **content**; chrome stays system size.

---

## Motion & vestibular

See [Motion.md § Reduced motion](./Motion.md#reduced-motion).

- Respect `accessibilityReduceMotion`
- No auto-playing parallax or pulsing “AI thinking” gradients
- Optional: reduce transparency when `accessibilityReduceTransparency` is true (avoid `Material` behind text)

---

## Testing checklist

### Manual (each release)

- [ ] VoiceOver walkthrough: unlock → create note → capture → AI panel → lock
- [ ] Keyboard-only: same path without mouse
- [ ] Increase Contrast on/off screenshot diff
- [ ] Reduce motion: sidebar, sheet, vault transitions
- [ ] Dynamic Type: largest content size in editor
- [ ] Accessibility Inspector: no unlabeled buttons

### Automated (future)

- Snapshot tests for token contrast pairs (script parsing `DesignTokens.swift`)
- UI tests posting `Cmd+Shift+N` for capture

### Bug severity

| Issue | Severity |
|-------|----------|
| Cannot unlock vault with VoiceOver | P0 |
| Missing label on primary nav | P1 |
| Contrast fail on secondary hint | P2 |
| Animation ignores reduce motion | P1 |

---

## Resources

- [Apple Accessibility for macOS](https://developer.apple.com/accessibility/macOS/)
- [WCAG 2.2 Quick Reference](https://www.w3.org/WAI/WCAG22/quickref/)
- OpenWrite tokens: [Tokens.md](./Tokens.md)

---

*See also: [OpenWriteDesignLanguage.md](./OpenWriteDesignLanguage.md) · [Components.md](./Components.md)*
