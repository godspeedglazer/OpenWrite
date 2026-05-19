# OpenWrite CLI

Native Swift command-line tools for indexing markdown notes and probing hybrid retrieval (no shell wrappers).

## Build & install

```bash
cd Tools/OpenWriteCLI
make install          # → /usr/local/bin/openwrite, openwrite-index, …
# or: PREFIX=$HOME/.local make install
```

## Binaries

| Tool | Role |
|------|------|
| `openwrite` | Multiplexer: `index`, `query`, `stats`, `test-queries` |
| `openwrite-index` | Rebuild `index.json` from a notes folder |
| `openwrite-query` | Hybrid search against an existing index |
| `openwrite-stats` | Chunk / page counts |

Defaults:

- Index: `~/Library/Application Support/openwrite/index.json`
- Notes: `~/Library/Application Support/openwrite/notes/`

## Examples

```bash
openwrite stats
openwrite index --notes ~/Documents/OpenWriteNotes
openwrite query "ingestion pipeline" --limit 5
openwrite test-queries --reindex
```

Fixture regression (from repo):

```bash
make test-queries
```

Sync app indexing sources after pulling: `make sync`.
