# OpenWrite

Native macOS local-first writer: encrypted vault, Note Design Language (NDL), and LM Studio–backed AI research.

## Requirements

- macOS 14.0+
- Xcode 15+

## Build

```bash
cd OpenWrite
xcodebuild -scheme OpenWrite -configuration Debug build
```

Open `OpenWrite/OpenWrite.xcodeproj` in Xcode and run the **OpenWrite** target.

## Repository layout

| Path | Description |
|------|-------------|
| `docs/OpenWriteMasterPlan.md` | Product vision, architecture, NDL v0, roadmap |
| `OpenWrite/` | Xcode project and Swift sources |
| `reor-main/` | Reference: local AI PKM (not linked into app) |
| `AFFiNE-canary/` | Reference: block editor patterns (not linked) |

## Bundle ID

`com.openwrite.app`

## Status

Phase 1 scaffold — buildable shell with core type stubs. See the master plan for MVP → v2 scope.
