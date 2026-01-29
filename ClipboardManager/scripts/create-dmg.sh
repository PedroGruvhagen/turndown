#!/bin/bash
#
# Create DMG installer for DemoskopClipboard
# Usage: ./scripts/create-dmg.sh
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"
BUILD_DIR="$PROJECT_DIR/build"
APP_NAME="DemoskopClipboard"
APP_BUNDLE="$BUILD_DIR/$APP_NAME.app"
VERSION=$(grep 'CFBundleShortVersionString' "$PROJECT_DIR/ClipboardManager/Info.plist" -A1 | tail -1 | sed 's/.*<string>\(.*\)<\/string>/\1/')
DMG_NAME="$APP_NAME-$VERSION"
DMG_PATH="$BUILD_DIR/$DMG_NAME.dmg"
DMG_TEMP="$BUILD_DIR/$DMG_NAME-temp.dmg"
VOLUME_NAME="$APP_NAME $VERSION"

echo "=== Creating DMG Installer ==="
echo "App Bundle: $APP_BUNDLE"
echo "Version: $VERSION"
echo "Output: $DMG_PATH"
echo ""

if [ ! -d "$APP_BUNDLE" ]; then
    echo "Error: App bundle not found at $APP_BUNDLE"
    echo "Run build-release.sh first."
    exit 1
fi

# Clean up old DMGs
rm -f "$DMG_PATH" "$DMG_TEMP"

# Create staging directory
STAGING_DIR="$BUILD_DIR/dmg-staging"
rm -rf "$STAGING_DIR"
mkdir -p "$STAGING_DIR"

# Copy app to staging
echo "Copying app to staging..."
cp -R "$APP_BUNDLE" "$STAGING_DIR/"

# Create symlink to Applications folder
ln -s /Applications "$STAGING_DIR/Applications"

# Create the DMG
echo "Creating DMG..."
hdiutil create -srcfolder "$STAGING_DIR" \
    -volname "$VOLUME_NAME" \
    -fs HFS+ \
    -fsargs "-c c=64,a=16,e=16" \
    -format UDRW \
    "$DMG_TEMP"

# Mount the DMG
echo "Mounting DMG for customization..."
MOUNT_POINT=$(hdiutil attach -readwrite -noverify -noautoopen "$DMG_TEMP" | awk '/\/Volumes\// {for(i=3;i<=NF;i++) printf "%s%s",$i,(i<NF?" ":""); print ""}')
echo "Mounted at: $MOUNT_POINT"

# Wait for mount
sleep 2

# Set window properties via AppleScript
echo "Customizing DMG window..."
osascript << EOF
tell application "Finder"
    tell disk "$VOLUME_NAME"
        open
        set current view of container window to icon view
        set toolbar visible of container window to false
        set statusbar visible of container window to false
        set bounds of container window to {400, 100, 920, 440}
        set viewOptions to the icon view options of container window
        set arrangement of viewOptions to not arranged
        set icon size of viewOptions to 80
        set position of item "$APP_NAME.app" of container window to {130, 170}
        set position of item "Applications" of container window to {390, 170}
        close
        open
        update without registering applications
        delay 2
        close
    end tell
end tell
EOF

# Unmount
echo "Unmounting..."
hdiutil detach "$MOUNT_POINT" -quiet

# Convert to compressed DMG
echo "Compressing DMG..."
hdiutil convert "$DMG_TEMP" \
    -format UDZO \
    -imagekey zlib-level=9 \
    -o "$DMG_PATH"

# Clean up
rm -f "$DMG_TEMP"
rm -rf "$STAGING_DIR"

# Sign the DMG (if Developer ID available)
echo ""
echo "Note: Sign the DMG with your Developer ID:"
echo "  codesign --force --sign 'Developer ID Application: YOUR_NAME (TEAM_ID)' '$DMG_PATH'"
echo ""

# Notarize the DMG
echo "To notarize the DMG:"
echo "  xcrun notarytool submit '$DMG_PATH' --apple-id 'your@email.com' --team-id 'TEAM_ID' --password '@keychain:AC_PASSWORD' --wait"
echo "  xcrun stapler staple '$DMG_PATH'"
echo ""

echo "=== DMG Created ==="
echo "Output: $DMG_PATH"
echo "Size: $(du -h "$DMG_PATH" | cut -f1)"
