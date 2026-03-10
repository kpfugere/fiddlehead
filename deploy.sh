#!/bin/bash
set -euo pipefail

APP_NAME="Fiddlehead"
SCHEME="Fiddlehead"
PROJECT="Fiddlehead.xcodeproj"
INSTALL_DIR="/Applications"
SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"

cd "$SCRIPT_DIR"

echo "==> Generating Xcode project..."
xcodegen generate

echo "==> Building Release..."
xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release build -quiet

# Find the built app in DerivedData
BUILD_DIR=$(xcodebuild -project "$PROJECT" -scheme "$SCHEME" -configuration Release -showBuildSettings 2>/dev/null \
    | grep -m1 '^\s*BUILT_PRODUCTS_DIR' | awk '{print $3}')

if [ ! -d "$BUILD_DIR/$APP_NAME.app" ]; then
    echo "ERROR: Built app not found at $BUILD_DIR/$APP_NAME.app"
    exit 1
fi

echo "==> Quitting $APP_NAME..."
osascript -e "quit app \"$APP_NAME\"" 2>/dev/null || true
sleep 1

echo "==> Installing to $INSTALL_DIR..."
rm -rf "$INSTALL_DIR/$APP_NAME.app"
cp -R "$BUILD_DIR/$APP_NAME.app" "$INSTALL_DIR/$APP_NAME.app"

echo "==> Launching $APP_NAME..."
open "$INSTALL_DIR/$APP_NAME.app"

echo "✓ $APP_NAME deployed successfully"
