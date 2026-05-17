# Image blocks (NDL v0)

**Status:** Shipped (paste + preview)

## Block model

- `NoteBlock.Kind.image`
- `text` — alt / caption
- `attributes["assetId"]` — UUID for `Application Support/openwrite/attachments/{assetId}.png`
- `attributes["path"]` — optional relative filename under `attachments/` (or absolute path)

## NDL line (plain editor + export)

```text
![Alt text](asset:550e8400-e29b-41d4-a716-446655440000)
```

Path form: `![Alt](path:screenshot.png)` or `![Alt](/full/path.png)`.

## Paste

1. Read `NSImage` from pasteboard (plain or block editor).
2. Save PNG via `VaultAttachmentStore`.
3. Insert markdown line (plain) or append `NoteBlock` (blocks).

## Preview

`OWPreviewBlockRow` loads the file from `VaultAttachmentStore.resolveFileURL(for:)`.
