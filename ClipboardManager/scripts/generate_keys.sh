#!/bin/bash
#
# Generate Ed25519 key pair for Sparkle auto-updates
# The public key goes in Info.plist (SUPublicEDKey)
# The private key is used to sign updates
#
# Usage: ./scripts/generate_keys.sh
#

set -e

SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_DIR="$( cd "$SCRIPT_DIR/.." && pwd )"

echo "=== Sparkle Ed25519 Key Generation ==="
echo ""

# Check if Sparkle is available via SPM
SPARKLE_CHECKOUT="$PROJECT_DIR/.build/checkouts/Sparkle"

if [ ! -d "$SPARKLE_CHECKOUT" ]; then
    echo "Sparkle not found in .build/checkouts/"
    echo "Running 'swift build' to fetch dependencies..."
    cd "$PROJECT_DIR"
    swift build
fi

# Look for generate_keys binary
GENERATE_KEYS=""

# Try to find it in Sparkle checkout
if [ -d "$SPARKLE_CHECKOUT" ]; then
    GENERATE_KEYS=$(find "$SPARKLE_CHECKOUT" -name "generate_keys" -type f 2>/dev/null | head -1)
fi

# If not found, try to use Sparkle's built-in signing tool
if [ -z "$GENERATE_KEYS" ] || [ ! -x "$GENERATE_KEYS" ]; then
    echo ""
    echo "generate_keys binary not found in Sparkle checkout."
    echo ""
    echo "Alternative: Generate keys manually using OpenSSL:"
    echo ""
    echo "  # Generate private key"
    echo "  openssl genpkey -algorithm Ed25519 -out sparkle_private_key.pem"
    echo ""
    echo "  # Extract public key (base64)"
    echo "  openssl pkey -in sparkle_private_key.pem -pubout -outform DER | tail -c 32 | base64"
    echo ""
    echo "Or download Sparkle directly from:"
    echo "  https://github.com/sparkle-project/Sparkle/releases"
    echo ""
    echo "The release ZIP contains bin/generate_keys"
    exit 1
fi

echo "Found generate_keys: $GENERATE_KEYS"
echo ""
echo "Generating Ed25519 key pair..."
echo ""

# Run the key generation
"$GENERATE_KEYS"

echo ""
echo "=== Key Generation Complete ==="
echo ""
echo "Next steps:"
echo "1. Copy the PUBLIC key to Info.plist as SUPublicEDKey"
echo "2. Store the PRIVATE key securely (e.g., in Keychain or encrypted file)"
echo "3. Use the private key to sign update DMGs with sign_update.sh"
