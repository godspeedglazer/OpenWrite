# Past Writes (optional module)

OpenWrite can surface a **timeline of writing sessions**—what you were working on, when, and a short excerpt—without requiring screen capture or OCR in v1.

## Relationship to rem+

**rem+** is a separate, user-authored macOS app (MIT) that records **screen memory** (frames, OCR text, timelines) into a local SQLite database. OpenWrite’s Past Writes module is inspired by the *concept* of turning ambient context into writing aid, but **does not ship or depend on rem+**.

- Integration is **optional**: `REMImportAdapter` looks for an existing rem+ `db.sqlite3` export path and is a stub in v1 (no SQLite parser in-tree yet).
- Patterns were reviewed clean-room from the rem+ fork under `rem-main/` (timeline + bounded context lines); OpenWrite implements vault-native session tracking instead.

## v1 scope

| In scope | Out of scope (later) |
|----------|----------------------|
| Index **vault edit history** into in-memory writing sessions | Full-disk edit log / CRDT sync |
| Inspector **Past Writes** timeline (6h / 24h / 7d) | Live screen OCR pipeline |
| `PastWritesService.recentContexts(since:)` for RAG hooks | rem+ frame thumbnails in-app |
| `snapshotSession(noteId:)` for per-note context | Constant-size traffic / DAITA-style padding |
| Optional **REM import** when `db.sqlite3` exists | Parsing rem+ `frames` / FTS tables |

## Data model

- **`SessionSnapshot`** — one writing session on a note: start/end, edit count, excerpt, source (`vaultEdits` | `remImport`).
- **`WritingContextEntry`** — lightweight row for UI and future AI context injection.

Sessions on the same note merge when edits occur within **30 minutes** of the previous edit (`PastWritesSessionPolicy.idleMergeInterval`).

## API

```swift
protocol PastWritesService: AnyObject {
    func recentContexts(since: Date) -> [WritingContextEntry]
    func snapshotSession(noteId: UUID) -> SessionSnapshot?
    func recordEdit(noteID: UUID, noteTitle: String, plainText: String)
}
```

Default implementation: `InMemoryPastWritesService` (v1). Persistence to vault sidecar JSON is a follow-up.

## UI

Workbench **inspector** → **Past Writes** tab → `PastWritesTimelineView`. When a note is selected, the list can filter to that note’s sessions.

## Privacy

- Default path: **only data already in the OpenWrite vault** (local, encrypted-at-rest when Phase 1 crypto is enabled).
- rem+ import: **opt-in by file presence**; operator must already run rem+ and store data on disk. OpenWrite does not start capture.

## Files

| Path | Role |
|------|------|
| `OpenWrite/Core/PastWrites/PastWritesService.swift` | Protocol + in-memory service |
| `OpenWrite/Core/PastWrites/SessionSnapshot.swift` | Models |
| `OpenWrite/Core/PastWrites/REMImportAdapter.swift` | rem+ SQLite path stub |
| `OpenWrite/UI/PastWrites/PastWritesTimelineView.swift` | Inspector timeline |

## License note

rem+ remains MIT in its own tree. OpenWrite Past Writes code is original to this repository; no rem+ source is linked at build time.
