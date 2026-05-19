#!/usr/bin/env bash
# Xcode build phase: compile OpenWrite CLI tools and copy into the app bundle.
set -euo pipefail

if [[ "${CONFIGURATION:-Debug}" != "Release" && "${EMBED_CLI_IN_DEBUG:-}" != "1" ]]; then
  echo "note: skipping CLI embed for ${CONFIGURATION:-Debug} (set EMBED_CLI_IN_DEBUG=1 to force)"
  exit 0
fi

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
CLI_DIR="$ROOT/Tools/OpenWriteCLI"
APP_HELPERS="${BUILT_PRODUCTS_DIR}/${WRAPPER_NAME}/Contents/Helpers"

mkdir -p "$APP_HELPERS"
cd "$CLI_DIR"
"$CLI_DIR/sync-core-sources.sh"
swift build -c release \
  --product openwrite \
  --product openwrite-index \
  --product openwrite-query \
  --product openwrite-stats

for tool in openwrite openwrite-index openwrite-query openwrite-stats; do
  install -m 755 "$CLI_DIR/.build/release/$tool" "$APP_HELPERS/$tool"
done

echo "Embedded CLI tools → $APP_HELPERS"
