#!/usr/bin/env bash
# ==============================================================================
# SECURE ANDROID RELEASE KEYSTORE GENERATOR (BASH)
# ==============================================================================

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANDROID_DIR="$PROJECT_ROOT/android"
APP_DIR="$ANDROID_DIR/app"
KEYSTORE_PATH="$APP_DIR/upload-keystore.jks"
KEY_PROPERTIES_PATH="$ANDROID_DIR/key.properties"

echo "=================================================================="
echo "       inRide Android Release Keystore Generator (Secure)"
echo "=================================================================="
echo ""

if [ -f "$KEYSTORE_PATH" ]; then
    echo "⚠️ A keystore already exists at: $KEYSTORE_PATH"
    read -rp "Do you want to overwrite it? (yes/no): " CONFIRM
    if [ "$CONFIRM" != "yes" ]; then
        echo "Operation cancelled."
        exit 0
    fi
fi

# Prompt for passwords securely without echo
read -rsp "Enter Keystore Password (min 8 chars): " PASS1
echo ""
read -rsp "Confirm Keystore Password: " PASS2
echo ""

if [ "${#PASS1}" -lt 8 ]; then
    echo "❌ Error: Password must be at least 8 characters long."
    exit 1
fi

if [ "$PASS1" != "$PASS2" ]; then
    echo "❌ Error: Passwords do not match."
    exit 1
fi

KEY_ALIAS="upload"
DNAME="CN=inRide, OU=Mobile, O=inRide, L=Cairo, ST=Cairo, C=EG"

echo "Generating release keystore (RSA 2048-bit)..."

keytool -genkeypair -v \
    -keystore "$KEYSTORE_PATH" \
    -alias "$KEY_ALIAS" \
    -keyalg RSA \
    -keysize 2048 \
    -validity 10000 \
    -storepass "$PASS1" \
    -keypass "$PASS1" \
    -dname "$DNAME"

cat <<EOF > "$KEY_PROPERTIES_PATH"
storeFile=app/upload-keystore.jks
storePassword=$PASS1
keyAlias=$KEY_ALIAS
keyPassword=$PASS1
EOF

echo ""
echo "=================================================================="
echo "✓ Keystore generated at: $KEYSTORE_PATH"
echo "✓ Local key.properties generated at: $KEY_PROPERTIES_PATH"
echo "=================================================================="
echo ""
echo "To convert keystore for GitHub Actions secret (ANDROID_KEYSTORE_BASE64):"
echo "  base64 -w 0 \"$KEYSTORE_PATH\" | pbcopy (or xclip -selection clipboard)"
echo ""
