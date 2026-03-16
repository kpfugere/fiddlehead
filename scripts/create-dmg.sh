#!/bin/bash
set -euo pipefail

APP_PATH="${1:?Usage: create-dmg.sh <path-to-app>}"
APP_NAME="Fiddlehead"
VERSION="${MARKETING_VERSION:-0.0.0}"
DMG_NAME="Fiddlehead-${VERSION}.dmg"
DMG_DIR="$(mktemp -d)"

echo "==> Creating DMG layout..."
cp -R "$APP_PATH" "$DMG_DIR/$APP_NAME.app"
ln -s /Applications "$DMG_DIR/Applications"

echo "==> Creating DMG: $DMG_NAME"
hdiutil create \
    -volname "$APP_NAME" \
    -srcfolder "$DMG_DIR" \
    -ov \
    -format UDZO \
    "$DMG_NAME"

rm -rf "$DMG_DIR"

echo "==> Done: $DMG_NAME"
