#!/bin/bash
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
ROOT_DIR="$(dirname "$SCRIPT_DIR")"

# Load version
source "$ROOT_DIR/version.env"

APP_NAME="SkillBar"
ZIP_NAME="$APP_NAME-$VERSION.zip"
ZIP_PATH="$ROOT_DIR/build/$ZIP_NAME"

# Step 1: Build app bundle
echo "==> Building app bundle..."
bash "$SCRIPT_DIR/package_app.sh"

# Step 2: Create ZIP
echo ""
echo "==> Creating release archive..."
cd "$ROOT_DIR/build"
ditto -c -k --keepParent "$APP_NAME.app" "$ZIP_NAME"
cd "$ROOT_DIR"

# Step 3: SHA256
SHA=$(shasum -a 256 "$ZIP_PATH" | awk '{print $1}')

echo ""
echo "==> Release artifact ready"
echo "    File: $ZIP_PATH"
echo "    SHA256: $SHA"
echo ""
echo "Next steps:"
echo "  1. git tag v$VERSION && git push origin v$VERSION"
echo "  2. Create GitHub release: gh release create v$VERSION $ZIP_PATH --title \"v$VERSION\""
echo "  3. Update Homebrew cask SHA256 to: $SHA"
