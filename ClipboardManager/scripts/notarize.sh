#!/bin/bash
#
# Notarize DemoskopClipboard app
#
# Prerequisites:
# 1. Apple Developer Program membership
# 2. Developer ID Application certificate installed
# 3. App-specific password stored in Keychain:
#    security add-generic-password -s "AC_PASSWORD" -a "your@email.com" -w "xxxx-xxxx-xxxx-xxxx"
#
# Usage: ./scripts/notarize.sh [TEAM_ID] [APPLE_ID]
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="DemoskopClipboard"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
ENTITLEMENTS="$BUILD_DIR/entitlements.plist"

# Configuration - replace with your values or pass as arguments
TEAM_ID="${1:-YOUR_TEAM_ID}"
APPLE_ID="${2:-your@email.com}"
KEYCHAIN_PROFILE="AC_PASSWORD"

echo "=== DemoskopClipboard Notarization ==="
echo "App Bundle: $APP_BUNDLE"
echo "Team ID: $TEAM_ID"
echo "Apple ID: $APPLE_ID"
echo ""

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found. Run build-release.sh first."
    exit 1
fi

# Step 1: Code Sign with Developer ID
echo "Step 1: Code signing with Developer ID..."
codesign --force --options runtime \
    --entitlements "$ENTITLEMENTS" \
    --sign "Developer ID Application: $TEAM_ID" \
    --timestamp \
    "$APP_BUNDLE"

echo "Verifying signature..."
codesign --verify --deep --strict --verbose=2 "$APP_BUNDLE"

# Step 2: Create ZIP for notarization
echo ""
echo "Step 2: Creating ZIP for notarization..."
ZIP_PATH="$BUILD_DIR/$APP_NAME.zip"
ditto -c -k --keepParent "$APP_BUNDLE" "$ZIP_PATH"
echo "ZIP created: $ZIP_PATH"

# Step 3: Submit for notarization
echo ""
echo "Step 3: Submitting to Apple for notarization..."
echo "This may take several minutes..."

xcrun notarytool submit "$ZIP_PATH" \
    --apple-id "$APPLE_ID" \
    --team-id "$TEAM_ID" \
    --password "@keychain:$KEYCHAIN_PROFILE" \
    --wait

# Step 4: Staple the notarization ticket
echo ""
echo "Step 4: Stapling notarization ticket..."
xcrun stapler staple "$APP_BUNDLE"

# Step 5: Verify stapling
echo ""
echo "Step 5: Verifying stapled app..."
xcrun stapler validate "$APP_BUNDLE"
spctl -a -t exec -vv "$APP_BUNDLE"

echo ""
echo "=== Notarization Complete ==="
echo "App is signed, notarized, and stapled."
echo ""
echo "Next steps:"
echo "1. Create DMG: ./scripts/create-dmg.sh"
echo "2. Or distribute the .app directly"
