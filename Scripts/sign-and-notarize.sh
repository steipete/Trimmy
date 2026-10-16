#!/usr/bin/env bash
set -euo pipefail

APP_NAME="Trimmy"
APP_IDENTITY="Developer ID Application: Peter Steinberger (Y5PE65HELJ)"
APP_BUNDLE="Trimmy.app"
ROOT=$(cd "$(dirname "$0")/.." && pwd)
APP_ENTITLEMENTS="$ROOT/Trimmy.entitlements"
source "$ROOT/version.env"
ZIP_NAME="Trimmy-${MARKETING_VERSION}.zip"
DSYM_ZIP="Trimmy-${MARKETING_VERSION}.dSYM.zip"

if [[ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" || -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]]; then
  echo "Missing APP_STORE_CONNECT_* env vars (API key, key id, issuer id)." >&2
  exit 1
fi
NOTARY_WORK_DIR=$(umask 077; mktemp -d "${TMPDIR:-/tmp}/trimmy-notarize.XXXXXX")
trap 'rm -rf "$NOTARY_WORK_DIR"' EXIT
NOTARY_KEY="$NOTARY_WORK_DIR/AuthKey.p8"
NOTARY_ZIP="$NOTARY_WORK_DIR/TrimmyNotarize.zip"
(umask 077; printf '%s\n' "$APP_STORE_CONNECT_API_KEY_P8" | sed 's/\\n/\n/g' > "$NOTARY_KEY")

# The packager performs a fresh arm64 release build.
./Scripts/package_app.sh release

echo "Signing with $APP_IDENTITY"
codesign --force --deep --options runtime --timestamp --entitlements "$APP_ENTITLEMENTS" --sign "$APP_IDENTITY" "$APP_BUNDLE"

# Zip for notarization (prefer system ditto)
DITTO_BIN=${DITTO_BIN:-/usr/bin/ditto}
"$DITTO_BIN" --norsrc -c -k --keepParent "$APP_BUNDLE" "$NOTARY_ZIP"

echo "Submitting for notarization"
xcrun notarytool submit "$NOTARY_ZIP" \
  --key "$NOTARY_KEY" \
  --key-id "$APP_STORE_CONNECT_KEY_ID" \
  --issuer "$APP_STORE_CONNECT_ISSUER_ID" \
  --wait

echo "Stapling ticket"
xcrun stapler staple "$APP_BUNDLE"

# Final zip for distribution
"$DITTO_BIN" --norsrc -c -k --keepParent "$APP_BUNDLE" "$ZIP_NAME"

# Verify
spctl -a -t exec -vv "$APP_BUNDLE"
xcrun stapler validate "$APP_BUNDLE"

echo "Packaging dSYM"
DSYM_PATH=".build/arm64-apple-macosx/release/Trimmy.dSYM"
if [[ ! -d "$DSYM_PATH" ]]; then
  echo "Missing dSYM at $DSYM_PATH" >&2
  exit 1
fi
"$DITTO_BIN" --norsrc -c -k --keepParent "$DSYM_PATH" "$DSYM_ZIP"

echo "Done: $ZIP_NAME and $DSYM_ZIP"
