#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Trimmy"
APP_IDENTITY="Developer ID Application: Peter Steinberger (Y5PE65HELJ)"
APP_BUNDLE="Trimmy.app"
ZIP_NAME="Trimmy-0.2.3.zip"

if [[ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" || -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  echo "Missing APP_STORE_CONNECT_* env vars (API key, key id, issuer id)." >&2
  exit 1
fi

echo "$APP_STORE_CONNECT_API_KEY_P8" | sed 's/\\n/\n/g' > /tmp/trimmy-api-key.p8
trap 'rm -f /tmp/trimmy-api-key.p8 /tmp/TrimmyNotarize.zip' EXIT

# Build arm64 only
swift build -c release --arch arm64
./Scripts/package_app.sh release

echo "Signing with $APP_IDENTITY"
codesign --force --deep --options runtime --timestamp --sign "$APP_IDENTITY" "$APP_BUNDLE"

# Zip for notarization (prefer system ditto)
DITTO_BIN=${DITTO_BIN:-/usr/bin/ditto}
"$DITTO_BIN" -c -k --keepParent "$APP_BUNDLE" /tmp/TrimmyNotarize.zip

echo "Submitting for notarization"
xcrun notarytool submit /tmp/TrimmyNotarize.zip \
  --key /tmp/trimmy-api-key.p8 \
  --key-id "$APP_STORE_CONNECT_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --wait

echo "Stapling ticket"
xcrun stapler staple "$APP_BUNDLE"

# Final zip for distribution
"$DITTO_BIN" -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

# Verify
spctl -a -t exec -vv "$APP_BUNDLE"
stapler validate "$APP_BUNDLE"

echo "Done: $ZIP_NAME"
