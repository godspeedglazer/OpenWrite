#!/usr/bin/env bash
# Build OpenWrite.app (Release) and install the app plus CLI tools to PATH.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
XCODE_DIR="$ROOT/OpenWrite"
SCHEME="OpenWrite"
APP_NAME="OpenWrite.app"
DEST_APP="${INSTALL_APP:-/Applications/$APP_NAME}"
BINDIR="${INSTALL_BIN_DIR:-/usr/local/bin}"

echo "==> Building $SCHEME (Release)…"
cd "$XCODE_DIR"
xcodebuild \
  -scheme "$SCHEME" \
  -configuration Release \
  -destination "platform=macOS" \
  build

BUILT_APP="$(find ~/Library/Developer/Xcode/DerivedData -path "*/Build/Products/Release/$APP_NAME" -print 2>/dev/null | head -1)"
if [[ -z "$BUILT_APP" || ! -d "$BUILT_APP" ]]; then
  echo "error: could not locate Release $APP_NAME in DerivedData" >&2
  exit 1
fi

HELPERS="$BUILT_APP/Contents/Helpers"
if [[ ! -x "$HELPERS/openwrite" ]]; then
  echo "error: CLI tools missing in bundle (expected $HELPERS/openwrite). Rebuild with Embed CLI Tools phase." >&2
  exit 1
fi

echo "==> Installing app → $DEST_APP"
sudo mkdir -p "$(dirname "$DEST_APP")"
sudo rm -rf "$DEST_APP"
sudo cp -R "$BUILT_APP" "$DEST_APP"

echo "==> Installing CLI tools → $BINDIR"
sudo mkdir -p "$BINDIR"
for tool in openwrite openwrite-index openwrite-query openwrite-stats; do
  sudo install -m 755 "$HELPERS/$tool" "$BINDIR/$tool"
done

echo ""
echo "Installed:"
echo "  App:  $DEST_APP"
echo "  CLI:  $BINDIR/openwrite (+ openwrite-index, openwrite-query, openwrite-stats)"
echo ""
echo "Try: openwrite stats && openwrite query \"your question\""
