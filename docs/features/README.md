# Feature specifications

**Last updated:** 2026-05-17

Per-feature documents describe **user-visible behavior**, acceptance criteria, and links to architecture and epics. Competitive status for each capability lives in [FeatureParityMatrix.md](../FeatureParityMatrix.md).

---

## Index

| Feature | Epic | Doc | Status |
|---------|------|-----|--------|
| Vault encryption | E-01 | [VaultEncryption.md](./VaultEncryption.md) | *Partial* |
| Vault navigation & file tree | E-08, E-07 | [VaultAndFileTree.md](./VaultAndFileTree.md) | *Spec* |
| Typed pages & structures | E-02 | [TypedPagesAndStructures.md](./TypedPagesAndStructures.md) | *Partial* |
| User-defined databases (OWDatabase) | v2 | [DatabasePresets.md](./DatabasePresets.md) | *Spec* |
| Backlinks & graph | E-06 | [GraphView.md](./GraphView.md) | *Partial* |
| Workbench shell | E-08 | [Workbench.md](./Workbench.md) | *Partial* |
| Import & export | E-07, E-10 | [ImportExport.md](./ImportExport.md) | *Partial* |
| Past Writes (sessions) | — | [PastWrites.md](./PastWrites.md) | *Partial* |
| NDL block editor | E-02 | [ndl-editor.md](./ndl-editor.md) | *Planned* |
| LM Studio RAG | E-03 | [lm-studio-rag.md](./lm-studio-rag.md) | *Planned* |
| FSEvents indexer | E-04 | — | *Planned* |
| Hybrid search | E-05 | [hybrid-search.md](./hybrid-search.md) | *Planned* |
| Fast capture | E-09 | [fast-capture.md](./fast-capture.md) | *Planned* |
| Publish pipeline | E-10 | — | *Planned (stub)* |

**Legacy kebab-case names** (`vault-encryption.md`, `workbench-shell.md`, etc.) are listed in [docs/README.md](../README.md) until migrated; prefer **PascalCase** filenames for new docs.

---

## How to add a feature doc

Follow [Contributing/DocumentationStandards.md](../Contributing/DocumentationStandards.md), then:

1. Add a row to this table and [docs/README.md](../README.md).
2. Add or update rows in [FeatureParityMatrix.md](../FeatureParityMatrix.md) with epic/ADR links.
3. Check the epic in [RoadmapEpics.md](../RoadmapEpics.md) when behavior ships.

---

## Cross-links

- Parity matrix: [FeatureParityMatrix.md](../FeatureParityMatrix.md)
- Epics: [RoadmapEpics.md](../RoadmapEpics.md)
- Architecture: [Architecture/Overview.md](../Architecture/Overview.md)
- AI: [Architecture/AI-Pipeline.md](../Architecture/AI-Pipeline.md)
- NDL: [NDL/Specification.md](../NDL/Specification.md)
