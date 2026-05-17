# ADR 0002: Typed pages without cloud sync

**Status:** Accepted  
**Date:** 2026-05-17  
**Deciders:** OpenWrite core team

## Context

Users expect structure beyond a single “note” type: tasks with due dates, references with URLs, journals with dates. Anytype provides rich object types and relations; OpenWrite cannot copy ASAL-licensed schemas.

We need **enough** structure for templates and inspector UI without building a full knowledge OS in v1.

## Decision

1. Introduce **`PageType`** enum: `note`, `task`, `reference`, `journal`, `project` (extensible registry later).
2. Store typed fields in **`PageProperties`** with per-type **schema** (`PageProperties.schema(for:)`).
3. Serialize properties as NDL **`@key value`** lines and/or JSON fields inside `VaultDocument`—JSON is canonical; NDL lines are editor/export view.
4. Provide **`TypeTemplate`** starter layouts per type.
5. **Defer** relations graph, kanban, and database views to v2+.

## Consequences

**Positive**

- Clearer inspector than plain Markdown front matter alone.
- Beats “install plugins for tasks” without Anytype complexity.
- Codable model ready for encrypted `.owdoc`.

**Negative**

- Not a full relational object model.
- Custom types require future registry work.
- Import from Obsidian front matter needs mapping tables.

## Alternatives considered

| Alternative | Why rejected |
|-------------|--------------|
| Markdown YAML only | Weak typing; poor round-trip in encrypted blob |
| Full Anytype-like relations | Scope trap; legal risk |
| Untyped notes only | Fails task/reference journeys |
| Single `metadata` string map | No schema validation or UI pickers |

## References

- `OpenWrite/OpenWrite/Models/PageType.swift`
- `OpenWrite/OpenWrite/Models/PageProperties.swift`
- [Architecture/DataModel.md](../Architecture/DataModel.md)
- [NDL/Specification.md § Property](../NDL/Specification.md#313-property-line-typed-pages)
