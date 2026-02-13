#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load version
source "$ROOT_DIR/version.env"

APP_NAME="SkillBar"
APP_DIR="$ROOT_DIR/build/$APP_NAME.app"
CONTENTS_DIR="$APP_DIR/Contents"

echo "==> Building $APP_NAME v$VERSION (build $BUILD_NUMBER)..."

# Step 1: Build release binary (arm64)
swift build -c release --package-path "$ROOT_DIR" --arch arm64

# Locate binary
BINARY="$ROOT_DIR/.build/arm64-apple-macosx/release/$APP_NAME"
if [ ! -f "$BINARY" ]; then
    echo "Error: Binary not found at $BINARY"
    exit 1
fi

# Step 2: Generate icon if missing
ICON="$ROOT_DIR/Resources/AppIcon.icns"
if [ ! -f "$ICON" ]; then
    echo "==> Generating app icon..."
    bash "$SCRIPT_DIR/generate_icon.sh"
fi

# Step 3: Create .app bundle structure
echo "==> Creating app bundle..."
rm -rf "$APP_DIR"
mkdir -p "$CONTENTS_DIR/MacOS" "$CONTENTS_DIR/Resources"

# Step 4: Copy binary
cp "$BINARY" "$CONTENTS_DIR/MacOS/$APP_NAME"

# Step 5: Generate Info.plist from template
sed -e "s/__VERSION__/$VERSION/g" \
    -e "s/__BUILD__/$BUILD_NUMBER/g" \
    "$ROOT_DIR/Resources/Info.plist.template" > "$CONTENTS_DIR/Info.plist"

# Step 6: Copy icon
cp "$ICON" "$CONTENTS_DIR/Resources/AppIcon.icns"

# Step 7: Ad-hoc code sign
echo "==> Signing (ad-hoc)..."
codesign --force --sign - --deep "$APP_DIR"

echo ""
echo "==> Success: $APP_DIR"
echo "    Version: $VERSION ($BUILD_NUMBER)"
echo "    Run: open $APP_DIR"
