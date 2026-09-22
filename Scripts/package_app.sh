#!/usr/bin/env bash
set -euo pipefail
CONF=${1:-debug}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# Load version info
source "$ROOT/version.env"

# Release packaging retains its clean-build guarantee; debug builds are incremental.
if [[ "$CONF" == "release" ]]; then
  swift package clean
fi

swift package resolve
python3 "$ROOT/Scripts/patch_keyboard_shortcuts.py" \
  "$ROOT/.build/checkouts/KeyboardShortcuts/Sources/KeyboardShortcuts/Utilities.swift"

BUILD_ARGS=(--build-system native -c "$CONF")
if [[ "$CONF" == "release" ]]; then
  BUILD_ARGS+=(--arch arm64)
fi
swift build "${BUILD_ARGS[@]}"
APP="$ROOT/Trimmy.app"
APP_ENTITLEMENTS="$ROOT/Trimmy.entitlements"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"
mkdir -p "$APP/Contents/Helpers"

ICON_TARGET="$ROOT/Icon.icns"

BUNDLE_ID="com.steipete.trimmy"
FEED_URL="https://raw.githubusercontent.com/steipete/Trimmy/main/appcast.xml"
AUTO_CHECKS=true
BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
if [[ "$CONF" == "debug" ]]; then
  BUNDLE_ID="com.steipete.trimmy.debug"
  FEED_URL=""
  AUTO_CHECKS=false
fi

cat > "$APP/Contents/Info.plist" <<PLIST
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Trimmy</string>
    <key>CFBundleDisplayName</key><string>Trimmy</string>
    <key>CFBundleIdentifier</key><string>${BUNDLE_ID}</string>
    <key>CFBundleExecutable</key><string>Trimmy</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>${MARKETING_VERSION}</string>
    <key>CFBundleVersion</key><string>${BUILD_NUMBER}</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>NSAppleEventsUsageDescription</key><string>Trimmy reads the active browser URL only to honor your site auto-trim blocklist.</string>
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>NSHumanReadableCopyright</key><string>2026 Peter Steinberger. MIT License.</string>
    <key>TrimmyBuildTimestamp</key><string>${BUILD_TIMESTAMP}</string>
    <key>TrimmyGitCommit</key><string>${GIT_COMMIT}</string>
    <key>SUFeedURL</key><string>${FEED_URL}</string>
    <key>SUPublicEDKey</key><string>AGCY8w5vHirVfGGDGc8Szc5iuOqupZSh9pMj/Qs67XI=</string>
    <key>SUEnableAutomaticChecks</key><${AUTO_CHECKS}/>
</dict>
</plist>
PLIST

cp ".build/$CONF/Trimmy" "$APP/Contents/MacOS/Trimmy"
chmod +x "$APP/Contents/MacOS/Trimmy"
# Ship TrimmyCLI alongside the app for easy symlinking.
if [[ -f ".build/$CONF/TrimmyCLI" ]]; then
  cp ".build/$CONF/TrimmyCLI" "$APP/Contents/Helpers/TrimmyCLI"
  chmod +x "$APP/Contents/Helpers/TrimmyCLI"
fi

# Keep resources inside the signed bundle layout; the localization patch resolves them here.
shopt -s nullglob
for bundle in ".build/$CONF/"*.bundle; do
  cp -R "$bundle" "$APP/Contents/Resources/"
done
shopt -u nullglob
# Require at least one SwiftPM resource bundle (KeyboardShortcuts) so packaging fails if resources are lost.
if ! ls "$APP/Contents/Resources/"*.bundle >/dev/null 2>&1; then
  echo "ERROR: No SwiftPM resource bundles copied into $APP/Contents/Resources (expected KeyboardShortcuts bundle)." >&2
  exit 1
fi

# Embed Sparkle.framework
if [[ -d ".build/$CONF/Sparkle.framework" ]]; then
  cp -R ".build/$CONF/Sparkle.framework" "$APP/Contents/Frameworks/"
  chmod -R a+rX "$APP/Contents/Frameworks/Sparkle.framework"
  install_name_tool -add_rpath "@executable_path/../Frameworks" "$APP/Contents/MacOS/Trimmy"
  CODESIGN_ID="${APP_IDENTITY:-Developer ID Application: Peter Steinberger (Y5PE65HELJ)}"
  function resign() { codesign --force --timestamp --options runtime --sign "$CODESIGN_ID" "$1"; }
  SPARKLE="$APP/Contents/Frameworks/Sparkle.framework"
  resign "$SPARKLE"
  resign "$SPARKLE/Versions/B/Sparkle"
  resign "$SPARKLE/Versions/B/Autoupdate"
  resign "$SPARKLE/Versions/B/Updater.app"
  resign "$SPARKLE/Versions/B/Updater.app/Contents/MacOS/Updater"
  resign "$SPARKLE/Versions/B/XPCServices/Downloader.xpc"
  resign "$SPARKLE/Versions/B/XPCServices/Downloader.xpc/Contents/MacOS/Downloader"
  resign "$SPARKLE/Versions/B/XPCServices/Installer.xpc"
  resign "$SPARKLE/Versions/B/XPCServices/Installer.xpc/Contents/MacOS/Installer"
  resign "$SPARKLE/Versions/B"
  resign "$SPARKLE"
fi
# Icon
if [[ -f "$ICON_TARGET" ]]; then
  cp "$ICON_TARGET" "$APP/Contents/Resources/Icon.icns"
fi

# Ensure contents are writable before stripping attributes and signing
chmod -R u+w "$APP"

# Strip extended attributes to avoid AppleDouble (._*) files that break code sealing
xattr -cr "$APP"
find "$APP" -name '._*' -delete

# Sign the app bundle after cleanup
CODESIGN_ID="${APP_IDENTITY:-Developer ID Application: Peter Steinberger (Y5PE65HELJ)}"
codesign --force --timestamp --options runtime --entitlements "$APP_ENTITLEMENTS" --sign "$CODESIGN_ID" "$APP"

echo "Created $APP"
