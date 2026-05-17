#!/usr/bin/env bash
# Generates OpenWrite AppIcon.appiconset placeholder (accent fill + OW monogram).
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
ICONSET="$ROOT/OpenWrite/OpenWrite/Assets.xcassets/AppIcon.appiconset"
MASTER="$ICONSET/icon_512x512@2x.png"

mkdir -p "$ICONSET"

swift - "$MASTER" <<'SWIFT'
import AppKit
import Foundation

let outputPath = CommandLine.arguments[1]
let size: CGFloat = 1024
let accent = NSColor(srgbRed: 0.227, green: 0.420, blue: 0.878, alpha: 1)

let image = NSImage(size: NSSize(width: size, height: size))
image.lockFocus()

accent.setFill()
NSBezierPath(rect: NSRect(x: 0, y: 0, width: size, height: size)).fill()

let text = "OW" as NSString
let font = NSFont.systemFont(ofSize: size * 0.36, weight: .bold)
let attributes: [NSAttributedString.Key: Any] = [
    .font: font,
    .foregroundColor: NSColor.white,
]
let textSize = text.size(withAttributes: attributes)
let textRect = NSRect(
    x: (size - textSize.width) / 2,
    y: (size - textSize.height) / 2 - size * 0.02,
    width: textSize.width,
    height: textSize.height
)
text.draw(in: textRect, withAttributes: attributes)

image.unlockFocus()

guard
    let tiff = image.tiffRepresentation,
    let rep = NSBitmapImageRep(data: tiff),
    let png = rep.representation(using: .png, properties: [:])
else {
    fputs("Failed to encode PNG\n", stderr)
    exit(1)
}

try png.write(to: URL(fileURLWithPath: outputPath))
SWIFT

# Downscale master to all macOS slots
declare -a SIZES=(16 32 128 256 512)
for base in "${SIZES[@]}"; do
  sips -z "$base" "$base" "$MASTER" --out "$ICONSET/icon_${base}x${base}.png" >/dev/null
  double=$((base * 2))
  sips -z "$double" "$double" "$MASTER" --out "$ICONSET/icon_${base}x${base}@2x.png" >/dev/null
done

echo "Wrote AppIcon placeholders to $ICONSET"
