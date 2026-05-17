# NDL Specification (v0)

**Note Design Language (NDL)** — version **0**  
**Last updated:** 2026-05-17  
**Status:** Draft standard; Phase 1 parser/serializer partial  
**Related:** [Migration.md](./Migration.md) · [Architecture/DataModel.md](../Architecture/DataModel.md) · [OpenWriteMasterPlan.md § NDL](../OpenWriteMasterPlan.md#note-dsl-spec-ndl-v0)

NDL is a **line-oriented, human-readable** serialization of a **block tree**. It is the canonical interchange inside encrypted `.owdoc` files. Markdown is export and import only—not the source of truth.

---

## 1. Normative keywords

The key words **MUST**, **MUST NOT**, **SHOULD**, **SHOULD NOT**, and **MAY** in this document are to be interpreted as described in RFC 2119 sense (informal for product spec).

---

## 2. Document model

### 2.1 Vault document

A **document** (page) consists of:

| Concept | Storage |
|---------|---------|
| Document id | `VaultDocument.id` (UUID) |
| Title | `title` + optional `properties[.title]` |
| Page type | `VaultDocument.pageType` |
| Properties | `PageProperties` (typed bag) |
| Body | `rootBlocks: [NoteBlock]` |

### 2.2 Block

Each **block** has:

| Field | Required | Description |
|-------|----------|-------------|
| `id` | YES | UUID v4, stable for life of block |
| `kind` | YES | Enumerated type |
| `text` | YES | Primary payload (may be empty) |
| `children` | YES | Array (may be empty) |
| `attributes` | YES | String map (may be empty) |

### 2.3 Forest structure

- `rootBlocks` is an ordered forest of top-level blocks.
- **Nesting:** child blocks live in `children` of parent.
- **v0 indent rule:** one level of nesting in serialized form = **2 ASCII spaces** before line prefix.
- Deeper trees MAY be represented in memory; serializer SHOULD flatten or reject beyond product max depth (default max depth: **8** for v0.1 validator).

---

## 3. Block kinds (v0)

### 3.1 Summary table

| Kind | Enum | Line form | `text` | `attributes` |
|------|------|-----------|--------|--------------|
| Paragraph | `paragraph` | plain line | body | — |
| Heading 1 | `heading1` | `# ` + title | title | — |
| Heading 2 | `heading2` | `## ` + title | title | — |
| Heading 3 | `heading3` | `### ` + title | title | — |
| Bullet | `bullet` | `- ` + body | body | — |
| Numbered | `numbered` | `N. ` + body | body | `start` optional |
| Todo | `todo` | `- [ ]` / `- [x]` | body | `checked` = `true`/`false` |
| Quote | `quote` | `> ` + body | body | — |
| Code | `code` | fenced ``` | source | `language` |
| Divider | `divider` | `---` alone | empty | — |
| Wikilink | `wikilink` | `[[…]]` | see §3.8 | — |
| Block ref | `blockref` | `((uuid))` | uuid string | — |
| Callout | `callout` | `> [!type]` + body | body | `callout` = note\|warning\|tip |
| Property | `property` | `@key value` | key fallback | `key`, `value` |

**Phase 1 parser today:** paragraph, heading1–3, bullet, quote, divider, wikilink (partial). **Serializer today:** above + code + property.

### 3.2 Paragraph

- One or more non-empty lines without matching another kind’s prefix form a paragraph block when using line-mode parser; canonical store prefers explicit `kind: paragraph`.

```
This is a paragraph line.
It may be stored as one block with embedded newlines in text (implementation choice).
```

**Recommendation:** one visual paragraph = one `NoteBlock` with single-line `text` in v0 editor; multiline via children or v0.1.

### 3.3 Headings

```
# Level one
## Level two
### Level three
```

- Leading `#` count MUST match kind.
- Space after hashes REQUIRED.
- Trailing hashes in setext style NOT supported in v0.

### 3.4 Bullet (outliner)

```
- Parent item
  - Child item
```

- Prefix: hyphen + space (`- `).
- Child: indent exactly **2 spaces** before `- `.

### 3.5 Numbered list

```
1. First
2. Second
```

- Decimal number, period, space.
- v0: list restarts at each interrupted blank line or non-numbered block.

### 3.6 Todo

```
- [ ] Open task
- [x] Done task
```

- Checkbox: space inside brackets for open; `x` or `X` for done.
- `attributes["checked"]` = `"true"` | `"false"`.

### 3.7 Quote

```
> Quoted text
```

### 3.8 Code fence

````
```swift
let x = 1
```
````

- Opening fence: ``` + optional language id (no whitespace before lang).
- Closing fence: ``` at column 0.
- `text` holds inner source without fences.
- `attributes["language"]` when present.

### 3.9 Divider

```
---
```

- Line MUST be exactly `---` at column 0 (no trailing spaces in strict mode).

### 3.10 Wikilink

```
[[Note Title]]
[[Note Title|550e8400-e29b-41d4-a716-446655440000]]
```

- `text` field encodes `title` or `title|uuid` (pipe separator).
- Parser MAY create block without uuid; resolver assigns on save.

### 3.11 Block reference

```
((a1b2c3d4-e5f6-7890-abcd-ef1234567890))
```

- `text` = target block UUID string.
- Transclusion rendering is UI concern.

### 3.12 Callout (v0 grammar reserved)

```
> [!note]
Body line
```

- `attributes["callout"]` = `note` | `warning` | `tip` | `important`

### 3.13 Property line (typed pages)

```
@title My Page
@tags alpha, beta
@dueDate 2026-05-20
```

- Maps to `NoteBlock.kind == .property`
- `attributes["key"]`, `attributes["value"]` preferred
- Keys align with `PagePropertyKey.rawValue`
- Values parsed by `PagePropertyValue(ndlPayload:for:)`

**Logseq-style alternative (export only, v0.1):** `key:: value` — not primary in OpenWrite serializer.

---

## 4. Block boundaries (serialization)

When serializing to linear NDL:

1. Adjacent blocks separated by **blank line** (`\n\n`).
2. Divider blocks own a line `---`.
3. Children serialized immediately after parent with 2-space indent on each line.
4. Property blocks for document MAY be emitted first via `NDLSerializer.serialize(document:)`.

---

## 5. Lexical grammar (informal EBNF)

```ebnf
document     ::= block_list ;
block_list   ::= block ( blank_line block )* ;
block        ::= property_line | prefixed_block | paragraph_line ;
blank_line   ::= "\n" "\n" ;

prefixed_block ::= divider | heading | bullet | numbered | todo | quote
                 | code_fence | wikilink | blockref | callout ;

divider      ::= "---" ;
heading      ::= "#" "#"? "#"? " " text ;
bullet       ::= "- " text ;
numbered     ::= digit+ "." " " text ;
todo         ::= "- [" (" " | "x" | "X") "] " text ;
quote        ::= "> " text ;
code_fence   ::= "```" lang? "\n" body "\n" "```" ;
wikilink     ::= "[[" inner "]]" ;
blockref     ::= "((" uuid "))" ;
callout      ::= "> [!" callout_type "]" "\n" text ;
property_line ::= "@" key " " value ;

paragraph_line ::= text ;   (* no leading structural prefix *)

indented_block ::= "  " prefixed_block ;   (* child *)
inner          ::= text | text "|" uuid ;
uuid           ::= 8-4-4-4-12 hex ;
key            ::= letter ( letter | digit )* ;
value          ::= any char except leading newline, unescaped ;
text           ::= UTF-8 printable, no BOM ;
```

---

## 6. Parser contract (`NDLParser`)

### 6.1 Entry points

```swift
enum NDLParser {
    static func parse(_ source: String) -> [NoteBlock]
}
```

### 6.2 Phase 1 behavior (current)

- Split on newlines, trim whitespace, drop empty lines.
- Each line → `parsePrefixedLine` or paragraph.
- **Does not** yet build `children` from indent (gap vs spec).

### 6.3 Target behavior (E-02)

1. Scan lines with indent level = `leadingSpaces / 2`.
2. Build tree using stack by indent.
3. Assign new UUID when missing on parse import.
4. Preserve ids when round-tripping existing documents.

### 6.4 Errors

| Mode | Behavior |
|------|----------|
| Strict | Fail parse with `NDLParseError` |
| Lenient (import) | Best-effort paragraph fallback |

---

## 7. Serializer contract (`NDLSerializer`)

```swift
enum NDLSerializer {
    static func serialize(blocks: [NoteBlock]) -> String
    static func serializeBlock(_ block: NoteBlock) -> String
    static func serialize(document: VaultDocument) -> String
}
```

### 7.1 Property value escaping

- If value contains newline → replace with `\n` escape sequence in output.

### 7.2 Wikilink

- Output `[[text]]` where text is stored payload.

---

## 8. Plain text extraction (indexing)

Implement `NoteBlock.plainTextRecursive` (planned extension):

- Walk tree; skip `divider`
- Headings contribute text + mark heading path
- Wikilink → title portion
- Property → `key: value`

Used by chunker and FTS — not part of on-disk NDL file.

---

## 9. Examples

### 9.1 Minimal note

```ndl
# Daily standup

What shipped yesterday.

- [ ] Write docs
- [x] Fix parser stub
```

### 9.2 Nested outline

```ndl
# Project OpenWrite

- Ship vault encryption
  - Keychain unlock flow
  - AEAD per .owdoc

> Principles beat features in v0.
```

### 9.3 Typed properties + wikilink

```ndl
@title Research backlog
@tags writing, ai

## Sources

[[Reor lineage|550e8400-e29b-41d4-a716-446655440000]]

See block ((a1b2c3d4-e5f6-7890-abcd-ef1234567890)) for definition.
```

### 9.4 Code

````ndl
## Build

```bash
cd OpenWrite && xcodebuild -scheme OpenWrite build
```
````

### 9.5 Reference page template (serialized document)

```ndl
@title Example Paper
@url https://example.org/paper
@author Jane Doe
@rating 4

# Example Paper

Source material and citations.

> Pull quotes go here.
````

---

## 10. Non-goals (v0)

- Full CommonMark compatibility
- Org-mode, tables, embeds, database views
- Collaborative CRDT / OT
- HTML inline in canonical store

---

## 11. Interchange

| Format | Direction | Fidelity |
|--------|-----------|----------|
| NDL string | canonical export view | Full for supported kinds |
| Markdown | import via `MarkdownImporter` | Partial |
| JSON `VaultDocument` | disk inside `.owdoc` | Full |

---

## 12. Conformance checklist

Implementers SHOULD verify:

- [ ] Round-trip: `parse(serialize(blocks))` preserves kinds and text for supported set
- [ ] UUID stable across serialize
- [ ] 2-space child indent
- [ ] Property keys match `PagePropertyKey`
- [ ] Wikilink pipe form parses uuid

---

## 13. Version identifier

Documents MAY record NDL version in `VaultDocument.metadata["ndlVersion"]` = `"0"`.

Future versions: see [Migration.md](./Migration.md).

---

## Related code

- `OpenWrite/OpenWrite/NoteDSL/NoteBlock.swift`
- `OpenWrite/OpenWrite/NoteDSL/NDLParser.swift`
- `OpenWrite/OpenWrite/NoteDSL/NDLSerializer` (in `NoteBlock.swift`)
