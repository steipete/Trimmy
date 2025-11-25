#!/usr/bin/env bash
set -euo pipefail
CONF=${1:-debug}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

# Load version info
source "$ROOT/version.env"

# Force a clean build to avoid stale binaries.
rm -rf "$ROOT/.build"
swift package clean >/dev/null 2>&1 || true

swift build -c "$CONF"
APP="$ROOT/Trimmy.app"
rm -rf "$APP"
mkdir -p "$APP/Contents/MacOS" "$APP/Contents/Resources" "$APP/Contents/Frameworks"

# Convert .icon (macOS 15 IconStudio format) to .icns if present
ICON_SOURCE="$ROOT/Icon.icon"
ICON_TARGET="$ROOT/Icon.icns"
if [[ -f "$ICON_SOURCE" ]]; then
  iconutil --convert icns --output "$ICON_TARGET" "$ICON_SOURCE"
fi

BUNDLE_ID="com.steipete.trimmy"
FEED_URL="https://raw.githubusercontent.com/steipete/Trimmy/main/appcast.xml"
AUTO_CHECKS=true
LOWER_CONF=$(printf "%s" "$CONF" | tr '[:upper:]' '[:lower:]')
BUILD_TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
GIT_COMMIT=$(git rev-parse --short HEAD 2>/dev/null || echo "unknown")
if [[ "$LOWER_CONF" == "debug" ]]; then
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
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>NSHumanReadableCopyright</key><string>© 2025 Peter Steinberger. MIT License.</string>
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

# Strip extended attributes to avoid AppleDouble (._*) files that break code sealing
xattr -cr "$APP"
find "$APP" -name '._*' -delete

# Sign the app bundle after cleanup
CODESIGN_ID="${APP_IDENTITY:-Developer ID Application: Peter Steinberger (Y5PE65HELJ)}"
codesign --force --timestamp --options runtime --sign "$CODESIGN_ID" "$APP"

echo "Created $APP"
