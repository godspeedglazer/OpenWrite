# OpenWrite

Native macOS local-first writer: on-disk notes, block editor (NDL), hybrid search, and LM Studio–backed AI.

**Bundle ID:** `com.openwrite.app` · **Requires:** macOS 14+, Xcode 15+

## Build

```bash
cd OpenWrite
xcodebuild -scheme OpenWrite -configuration Debug -destination 'platform=macOS' build
```

Open `OpenWrite/OpenWrite.xcodeproj` in Xcode and run the **OpenWrite** target.

## Install (app + CLI)

Release builds embed CLI tools in `OpenWrite.app/Contents/Helpers/`.

```bash
./scripts/install-openwrite.sh
```

The app also installs `openwrite` into `~/.local/bin` on first launch (Settings → AI → **Install CLI tools**).

## Command-line tools

```bash
cd Tools/OpenWriteCLI && make install
openwrite index
openwrite query "your question" --limit 5
```

See [Tools/OpenWriteCLI/README.md](Tools/OpenWriteCLI/README.md).

## Repository layout

| Path | Description |
|------|-------------|
| `OpenWrite/` | Xcode app (SwiftUI, editor, indexing, RAG, shell) |
| `Tools/OpenWriteCLI/` | `openwrite`, `openwrite-index`, `openwrite-query`, `openwrite-stats` |
| `scripts/` | Release embed + `/Applications` installer |

Planning docs under `docs/` are kept **local only** (not on GitHub).
