#!/usr/bin/env bash
# Regenerate macOS AppIcon.appiconset from OpenWriteLogo source PNG.
set -euo pipefail
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
SRC="${1:-$ROOT/OpenWrite/OpenWrite/Assets.xcassets/OpenWriteLogo.imageset/openwritelogo.png}"
DEST="$ROOT/OpenWrite/OpenWrite/Assets.xcassets/AppIcon.appiconset"

if [[ ! -f "$SRC" ]]; then
  echo "Source logo not found: $SRC" >&2
  exit 1
fi

for size in 16 32 128 256 512; do
  sips -z "$size" "$size" "$SRC" --out "$DEST/icon_${size}x${size}.png" >/dev/null
  sips -z "$((size * 2))" "$((size * 2))" "$SRC" --out "$DEST/icon_${size}x${size}@2x.png" >/dev/null
done

echo "Wrote AppIcon sizes into $DEST"
