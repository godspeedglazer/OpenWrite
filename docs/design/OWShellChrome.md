# OW Shell Chrome — custom window framework (direction)

OpenWrite cannot rely on default `NSWindow` titlebar vibrancy: on launch macOS paints a **system-grey** strip above `contentLayoutRect` that fights our cream shell. The long-term fix is an **OW Shell** layer that owns window chrome end-to-end, not one-off AppKit hacks per release.

## Layers (today → target)

| Layer | Role | Location |
|-------|------|----------|
| **OWWindowChrome** | AppKit window policy: transparent titlebar, opaque fill, vibrancy strip, theme paint | `UI/Shell/OWWindowChrome.swift` |
| **OWShellTitleBar** | SwiftUI title + tabs + brand | `UI/Shell/OWWindowChrome.swift` |
| **OWShellWindowControls** | Custom close / minimize / zoom (muted squares) | same |
| **DesignTokens + ThemePalette** | `shellChrome`, control metrics, safe-area heights | `DesignTokens.swift`, `ThemePalette.swift` |
| **OWComponents** | In-window controls (buttons, fields, scroll) | `docs/design/OWComponents.md` |

## Current policy (`usesCustomWindowControls = true`)

1. Hide native traffic lights.
2. Draw **OWShellWindowControls** in the title bar.
3. Install **OWSolidTitlebarAccessory** (opaque `shellChrome`) so the non-client strip is never Apple grey.
4. Re-apply chrome on `didBecomeVisible`, theme change, resize, and fullscreen.

## Roadmap (framework, not hacks)

1. **Phase A (done)** — Reliable cream titlebar + custom controls on standard `NSWindow`.
2. **Phase B (done)** — `OWSolidTitlebarAccessory` paints opaque `shellChrome` with `hitTest` pass-through so SwiftUI controls stay clickable; fullscreen re-applies chrome on enter/exit.
3. **Phase C** — Optional borderless / `NSPanel`-style host for graph-only or minimal windows; shared metrics API.
4. **Phase D** — Extract public-style module boundaries: `OWChrome`, `OWTheme`, `OWControls` (still in-repo; not a separate package until needed).

Agents should extend **OWWindowChrome** and **DesignTokens** rather than adding per-view `NSAppearance` tweaks.
