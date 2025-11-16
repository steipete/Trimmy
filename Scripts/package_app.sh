#!/usr/bin/env bash
set -euo pipefail
CONF=${1:-debug}
ROOT=$(cd "$(dirname "$0")/.." && pwd)
cd "$ROOT"

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

cat > "$APP/Contents/Info.plist" <<'PLIST'
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>CFBundleName</key><string>Trimmy</string>
    <key>CFBundleDisplayName</key><string>Trimmy</string>
    <key>CFBundleIdentifier</key><string>com.steipete.trimmy</string>
    <key>CFBundleExecutable</key><string>Trimmy</string>
    <key>CFBundlePackageType</key><string>APPL</string>
    <key>CFBundleShortVersionString</key><string>0.2.2</string>
    <key>CFBundleVersion</key><string>6</string>
    <key>LSMinimumSystemVersion</key><string>15.0</string>
    <key>LSUIElement</key><true/>
    <key>CFBundleIconFile</key><string>Icon</string>
    <key>NSHumanReadableCopyright</key><string>© 2025 Peter Steinberger. MIT License.</string>
    <key>SUFeedURL</key><string>https://raw.githubusercontent.com/steipete/Trimmy/main/appcast.xml</string>
    <key>SUPublicEDKey</key><string>AGCY8w5vHirVfGGDGc8Szc5iuOqupZSh9pMj/Qs67XI=</string>
    <key>SUEnableAutomaticChecks</key><true/>
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
fi
# Icon
if [[ -f "$ICON_TARGET" ]]; then
  cp "$ICON_TARGET" "$APP/Contents/Resources/Icon.icns"
fi

echo "Created $APP"
