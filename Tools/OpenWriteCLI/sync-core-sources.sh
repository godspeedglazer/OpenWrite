#!/usr/bin/env bash
# Link/copy minimal OpenWrite sources for the retrieval CLI (no AppKit / LM Studio).
set -euo pipefail
ROOT="$(cd "$(dirname "$0")" && pwd)"
OW="$ROOT/../../OpenWrite/OpenWrite"
DEST="$ROOT/Sources/OpenWriteCore"
rm -rf "$DEST"
mkdir -p "$DEST"

link() {
  local rel="$1"
  local dir="$DEST/$(dirname "$rel")"
  mkdir -p "$dir"
  ln -sf "$OW/$rel" "$DEST/$rel"
}

for rel in \
  AI/AISafetyLimits.swift \
  Core/Indexing/IndexChunk.swift \
  Core/Indexing/IngestionHealth.swift \
  Core/Indexing/InMemoryVectorStore.swift \
  Core/Indexing/VaultIndexEntry.swift \
  Core/Retrieval/HybridRanker.swift \
  Core/Retrieval/RetrievalQueryAnalysis.swift \
  Core/Retrieval/RetrievalService.swift \
  Import/MarkdownImporter.swift \
  Models/PageType.swift \
  Models/PageProperties.swift \
  NoteDSL/NDLParser.swift \
  NoteDSL/BlockRefinement.swift \
  NoteDSL/RefinePrompts.swift \
  AI/OWActionScript.swift \
  Import/RichPasteImporter.swift \
  UI/Editor/BlockKeyboardEditing.swift
do
  link "$rel"
done

rm -f "$DEST/NoteDSL/NoteBlock.swift"
cp "$OW/NoteDSL/NoteBlock.swift" "$DEST/NoteDSL/NoteBlock.swift"
sed -i '' '/static func serialize(document: VaultDocument)/,/^    }$/d' \
  "$DEST/NoteDSL/NoteBlock.swift"
sed -i '' '/static func propertyBlocks(from properties: PageProperties/,/^    }$/d' \
  "$DEST/NoteDSL/NoteBlock.swift"
# Remove orphan doc comment left by sed.
sed -i '' '/Front-matter style property section/d' "$DEST/NoteDSL/NoteBlock.swift"

mkdir -p "$DEST/AI"
awk '/^extension Notification.Name/{exit} {print}' "$OW/AI/EmbeddingService.swift" > "$DEST/AI/EmbeddingService.swift"

mkdir -p "$DEST/Core/Indexing"
awk 'NR<17 || NR>49' "$OW/Core/Indexing/IndexerService.swift" > "$DEST/Core/Indexing/IndexerService.swift"

mkdir -p "$DEST/Core/Vault"
cat > "$DEST/Core/Vault/CLINotesScanPolicy.swift" <<'EOF'
import Foundation

enum CLINotesScanPolicy {
    static let hiddenDirectoryNames: Set<String> = [".openwrite", ".git", ".obsidian", "node_modules"]
}
EOF

cp "$OW/Core/Vault/VaultMarkdownCatalog.swift" "$DEST/Core/Vault/VaultMarkdownCatalog.swift"
sed -i '' 's/VaultLocationPreferences\.hiddenDirectoryNames/CLINotesScanPolicy.hiddenDirectoryNames/g' \
  "$DEST/Core/Vault/VaultMarkdownCatalog.swift"

echo "Synced minimal OpenWrite core → $DEST"
