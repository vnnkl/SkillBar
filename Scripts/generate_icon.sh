#!/bin/bash
set -euo pipefail

# Generate AppIcon.icns from SF Symbol "terminal"
# Requires macOS with sips and iconutil

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"
RESOURCES_DIR="$ROOT_DIR/Resources"
ICONSET_DIR="$ROOT_DIR/build/AppIcon.iconset"

mkdir -p "$ICONSET_DIR" "$RESOURCES_DIR"

# Render SF Symbol "terminal" to a 1024x1024 PNG using Swift
MASTER_PNG="$ROOT_DIR/build/icon_master.png"

/usr/bin/swift - "$MASTER_PNG" <<'SWIFT'
import AppKit

let outputPath = CommandLine.arguments[1]
let size = NSSize(width: 1024, height: 1024)

let image = NSImage(size: size, flipped: false) { rect in
    // Background: rounded rectangle with gradient
    let bgPath = NSBezierPath(roundedRect: rect.insetBy(dx: 40, dy: 40), xRadius: 180, yRadius: 180)

    // Dark gradient background
    let gradient = NSGradient(
        starting: NSColor(red: 0.15, green: 0.15, blue: 0.20, alpha: 1.0),
        ending: NSColor(red: 0.08, green: 0.08, blue: 0.12, alpha: 1.0)
    )!
    gradient.draw(in: bgPath, angle: -90)

    // Border
    NSColor(white: 0.3, alpha: 0.5).setStroke()
    bgPath.lineWidth = 4
    bgPath.stroke()

    // SF Symbol "terminal"
    let config = NSImage.SymbolConfiguration(pointSize: 420, weight: .medium)
    if let symbol = NSImage(systemSymbolName: "terminal", accessibilityDescription: nil)?
        .withSymbolConfiguration(config) {
        let symbolSize = symbol.size
        let x = (rect.width - symbolSize.width) / 2
        let y = (rect.height - symbolSize.height) / 2
        let drawRect = NSRect(x: x, y: y, width: symbolSize.width, height: symbolSize.height)

        NSColor(red: 0.55, green: 0.8, blue: 1.0, alpha: 0.95).set()
        symbol.draw(in: drawRect, from: .zero, operation: .sourceOver, fraction: 1.0)

        // Tint by drawing over with source atop
        NSColor(red: 0.55, green: 0.8, blue: 1.0, alpha: 0.95).set()
        drawRect.fill(using: .sourceAtop)
    }

    return true
}

guard let tiff = image.tiffRepresentation,
      let bitmap = NSBitmapImageRep(data: tiff),
      let png = bitmap.representation(using: .png, properties: [:]) else {
    fputs("Error: Failed to render icon\n", stderr)
    exit(1)
}

do {
    try png.write(to: URL(fileURLWithPath: outputPath))
} catch {
    fputs("Error: \(error)\n", stderr)
    exit(1)
}
SWIFT

if [ ! -f "$MASTER_PNG" ]; then
    echo "Error: Failed to generate master icon"
    exit 1
fi

echo "Generated master icon: $MASTER_PNG"

# Generate all required iconset sizes
SIZES=(16 32 128 256 512)
for s in "${SIZES[@]}"; do
    sips -z "$s" "$s" "$MASTER_PNG" --out "$ICONSET_DIR/icon_${s}x${s}.png" >/dev/null
    d=$((s * 2))
    sips -z "$d" "$d" "$MASTER_PNG" --out "$ICONSET_DIR/icon_${s}x${s}@2x.png" >/dev/null
done

# iconutil requires all standard sizes; 512@2x = 1024
cp "$MASTER_PNG" "$ICONSET_DIR/icon_512x512@2x.png"

# Convert iconset to icns
iconutil -c icns "$ICONSET_DIR" -o "$RESOURCES_DIR/AppIcon.icns"

# Cleanup
rm -rf "$ICONSET_DIR" "$MASTER_PNG"

echo "Generated: $RESOURCES_DIR/AppIcon.icns"
