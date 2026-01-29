#!/bin/bash
#
# Build ClipboardManager for release
# Usage: ./scripts/build-release.sh
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="DemoskopClipboard"
VERSION=$(grep 'CFBundleShortVersionString' "$PROJECT_DIR/ClipboardManager/Info.plist" -A1 | tail -1 | sed 's/.*<string>\(.*\)<\/string>/\1/')

echo "=== Demoskop Clipboard Release Build ==="
echo "Version: $VERSION"
echo "Project: $PROJECT_DIR"
echo "Build Dir: $BUILD_DIR"
echo ""

# Clean previous builds
echo "Cleaning previous builds..."
rm -rf "$BUILD_DIR"
mkdir -p "$BUILD_DIR"

# Build release with Swift Package Manager
echo "Building release configuration..."
cd "$PROJECT_DIR"
swift build -c release

# Get the built executable path
EXECUTABLE_PATH="$PROJECT_DIR/.build/release/$APP_NAME"

if [ ! -f "$EXECUTABLE_PATH" ]; then
    echo "Error: Built executable not found at $EXECUTABLE_PATH"
    exit 1
fi

echo "Executable built at: $EXECUTABLE_PATH"

# Create .app bundle structure
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
CONTENTS_DIR="$APP_BUNDLE/Contents"
MACOS_DIR="$CONTENTS_DIR/MacOS"
RESOURCES_DIR="$CONTENTS_DIR/Resources"

echo "Creating app bundle structure..."
mkdir -p "$MACOS_DIR"
mkdir -p "$RESOURCES_DIR"

# Copy executable
cp "$EXECUTABLE_PATH" "$MACOS_DIR/$APP_NAME"

# Copy Info.plist (substitute variables)
cat "$PROJECT_DIR/ClipboardManager/Info.plist" | \
    sed "s/\$(DEVELOPMENT_LANGUAGE)/en/" | \
    sed "s/\$(EXECUTABLE_NAME)/$APP_NAME/" | \
    sed "s/\$(PRODUCT_BUNDLE_IDENTIFIER)/se.demoskop.clipboard/" | \
    sed "s/\$(PRODUCT_NAME)/$APP_NAME/" | \
    sed "s/\$(PRODUCT_BUNDLE_PACKAGE_TYPE)/APPL/" | \
    sed "s/\$(MACOSX_DEPLOYMENT_TARGET)/13.0/" \
    > "$CONTENTS_DIR/Info.plist"

# Create PkgInfo
echo -n "APPL????" > "$CONTENTS_DIR/PkgInfo"

# Copy entitlements for signing reference
cp "$PROJECT_DIR/ClipboardManager/ClipboardManager.entitlements" "$BUILD_DIR/entitlements.plist"

echo ""
echo "=== Build Complete ==="
echo "App Bundle: $APP_BUNDLE"
echo "Entitlements: $BUILD_DIR/entitlements.plist"
echo ""
echo "Next steps:"
echo "1. Code sign: codesign --force --options runtime --entitlements $BUILD_DIR/entitlements.plist --sign 'Developer ID Application: YOUR_NAME (TEAM_ID)' '$APP_BUNDLE'"
echo "2. Notarize: See scripts/notarize.sh"
echo "3. Create DMG: See scripts/create-dmg.sh"
