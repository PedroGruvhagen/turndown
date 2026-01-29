#!/bin/bash
#
# Sign update DMG/ZIP with Ed25519 private key for Sparkle
# The signature is included in appcast.xml as sparkle:edSignature
#
# Usage: ./scripts/sign_update.sh <path_to_dmg_or_zip>
#

set -e

if [ -z "$1" ]; then
    echo "Usage: $0 <path_to_dmg_or_zip>"
    echo ""
    echo "Example:"
    echo "  $0 build/DemoskopClipboard-1.0.0.dmg"
    exit 1
fi

UPDATE_FILE="$1"

if [ ! -f "$UPDATE_FILE" ]; then
    echo "Error: File not found: $UPDATE_FILE"
    exit 1
fi

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=== Sparkle Update Signing ==="
echo "File: $UPDATE_FILE"
echo ""

# Check if Sparkle is available via SPM
SPARKLE_CHECKOUT="$PROJECT_DIR/.build/checkouts/Sparkle"

if [ ! -d "$SPARKLE_CHECKOUT" ]; then
    echo "Sparkle not found in .build/checkouts/"
    echo "Running 'swift build' to fetch dependencies..."
    cd "$PROJECT_DIR"
    swift build
fi

# Look for sign_update binary
SIGN_UPDATE=""

if [ -d "$SPARKLE_CHECKOUT" ]; then
    SIGN_UPDATE=$(find "$SPARKLE_CHECKOUT" -name "sign_update" -type f 2>/dev/null | head -1)
fi

# If not found, provide alternative
if [ -z "$SIGN_UPDATE" ] || [ ! -x "$SIGN_UPDATE" ]; then
    echo ""
    echo "sign_update binary not found in Sparkle checkout."
    echo ""
    echo "Alternative: Sign manually using OpenSSL:"
    echo ""
    echo "  # Sign the file"
    echo "  openssl pkeyutl -sign -inkey sparkle_private_key.pem \\"
    echo "    -rawin -in <(cat \"$UPDATE_FILE\" | openssl dgst -sha512 -binary) | base64"
    echo ""
    echo "Or download Sparkle directly from:"
    echo "  https://github.com/sparkle-project/Sparkle/releases"
    echo ""
    echo "The release ZIP contains bin/sign_update"
    exit 1
fi

echo "Found sign_update: $SIGN_UPDATE"
echo ""
echo "Signing update..."
echo ""

# Run the signing tool
# It will prompt for the private key or use the one in Keychain
SIGNATURE=$("$SIGN_UPDATE" "$UPDATE_FILE")

echo "=== Signature Generated ==="
echo ""
echo "Add this to your appcast.xml:"
echo ""
echo "  sparkle:edSignature=\"$SIGNATURE\""
echo ""
echo "Full enclosure example:"
echo "  <enclosure"
echo "    url=\"https://your-site.com/DemoskopClipboard-1.0.0.dmg\""
echo "    sparkle:edSignature=\"$SIGNATURE\""
echo "    length=\"$(stat -f%z "$UPDATE_FILE")\""
echo "    type=\"application/octet-stream\"/>"
