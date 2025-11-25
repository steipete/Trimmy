#!/usr/bin/env bash
# Trimmy one-shot release helper.
# Usage: Scripts/release.sh [marketing_version] [build_number] [release-notes-file]
# If no version/build args are provided, values from version.env are used.

set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$ROOT"
source "$ROOT/version.env"

LOG() { printf "==> %s\n" "$*"; }
ERR() { printf "ERROR: %s\n" "$*" >&2; exit 1; }

if [[ $# -ge 2 ]]; then
  VERSION="$1"
  BUILD="$2"
  NOTES_FILE="${3:-}"
else
  VERSION="$MARKETING_VERSION"
  BUILD="$BUILD_NUMBER"
  NOTES_FILE="${1:-}"
fi

ZIP_NAME="Trimmy-${VERSION}.zip"
DSYM_ZIP="Trimmy-${VERSION}.dSYM.zip"

require() {
  command -v "$1" >/dev/null || ERR "Missing required command: $1"
}

require git
require swiftlint
require swift
require sign_update
require gh
require zip
require curl

[[ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" || -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]] && \
  ERR "APP_STORE_CONNECT_* env vars must be set."
[[ -z "${SPARKLE_PRIVATE_KEY_FILE:-}" ]] && ERR "SPARKLE_PRIVATE_KEY_FILE must be set."
[[ -f "$SPARKLE_PRIVATE_KEY_FILE" ]] || ERR "SPARKLE_PRIVATE_KEY_FILE not found at $SPARKLE_PRIVATE_KEY_FILE"

git diff --quiet || ERR "Working tree is not clean."

update_file_versions() {
  LOG "Bumping versions to $VERSION ($BUILD)"
  python - "$VERSION" "$BUILD" <<'PY' || ERR "Failed to bump versions"
import sys, pathlib, re
ver, build = sys.argv[1], sys.argv[2]

def repl(path: pathlib.Path, pattern: str, replacement: str):
    text = path.read_text()
    new, n = re.subn(pattern, replacement, text, flags=re.M)
    if n == 0:
        raise SystemExit(f"no match in {path}")
    path.write_text(new)

repl(pathlib.Path("Scripts/package_app.sh"),
     r'(CFBundleShortVersionString</key><string>)([^<]+)',
     rf"\1{ver}")
repl(pathlib.Path("Scripts/package_app.sh"),
     r'(CFBundleVersion</key><string>)([^<]+)',
     rf"\1{build}")
repl(pathlib.Path("Scripts/sign-and-notarize.sh"),
     r'^(ZIP_NAME=)"Trimmy-[^"]+\.zip"$',
     rf'\1"Trimmy-{ver}.zip"')
PY
}

update_changelog_header() {
  LOG "Ensuring changelog header is dated for $VERSION"
  python - "$VERSION" <<'PY' || ERR "Failed to update CHANGELOG"
import sys, pathlib, re, datetime
ver = sys.argv[1]
today = datetime.date.today().strftime("%Y-%m-%d")
p = pathlib.Path("CHANGELOG.md")
text = p.read_text()
pat = re.compile(rf"^##\s+{re.escape(ver)}\s+—\s+.*?(unreleased)?", re.M | re.I)
new, n = pat.subn(f"## {ver} — {today}", text, count=1)
if n == 0:
    sys.exit("Changelog section not found for version")
p.write_text(new)
PY
}

run_quality_gates() {
  LOG "Running swiftlint"
  swiftlint --strict
  LOG "Running swift test"
  swift test
}

build_and_notarize() {
  LOG "Building, signing, notarizing"
  ./Scripts/sign-and-notarize.sh
}

zip_dsym() {
  if [[ -f "$DSYM_ZIP" ]]; then
    LOG "dSYM zip already present ($DSYM_ZIP)"
    return
  fi
  LOG "Zipping dSYM"
  local dsym_dir=".build/arm64-apple-macosx/release/Trimmy.dSYM"
  [[ -d "$dsym_dir" ]] || ERR "dSYM not found at $dsym_dir"
  rm -f "$DSYM_ZIP"
  /usr/bin/ditto -c -k --keepParent "$dsym_dir" "$DSYM_ZIP"
}

sign_zip() {
  LOG "Generating Sparkle signature"
  SIGNATURE=$(sign_update --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" -p "$ZIP_NAME")
  SIZE=$(stat -f%z "$ZIP_NAME")
}

update_appcast() {
  LOG "Updating appcast.xml"
  local pubdate
  pubdate=$(LC_ALL=C date '+%a, %d %b %Y %H:%M:%S %z')
  python - "$VERSION" "$BUILD" "$SIGNATURE" "$SIZE" "$pubdate" <<'PY' || exit 1
import sys, pathlib
ver, build, sig, size, pub = sys.argv[1:]
path = pathlib.Path("appcast.xml")
xml = path.read_text()
entry = f"""        <item>
            <title>{ver}</title>
            <pubDate>{pub}</pubDate>
            <link>https://raw.githubusercontent.com/steipete/Trimmy/main/appcast.xml</link>
            <sparkle:version>{build}</sparkle:version>
            <sparkle:shortVersionString>{ver}</sparkle:shortVersionString>
            <sparkle:minimumSystemVersion>15.0</sparkle:minimumSystemVersion>
            <enclosure url="https://github.com/steipete/Trimmy/releases/download/v{ver}/Trimmy-{ver}.zip" length="{size}" type="application/octet-stream" sparkle:edSignature="{sig}"/>
        </item>
"""
marker = "<channel>"
idx = xml.find(marker)
if idx == -1:
    raise SystemExit("no <channel> in appcast")
insert_at = xml.find("\n", idx) + 1
path.write_text(xml[:insert_at] + entry + xml[insert_at:])
PY
}

create_tag_and_release() {
  LOG "Creating tag v$VERSION"
  git add CHANGELOG.md Scripts/package_app.sh Scripts/sign-and-notarize.sh appcast.xml
  git commit -m "Release $VERSION (build $BUILD)"
  git tag "v$VERSION"
  LOG "Pushing main and tag"
  git push origin main
  git push origin "v$VERSION"

  LOG "Uploading artifacts to GitHub release"
  local notes_arg=()
  [[ -n "$NOTES_FILE" ]] && notes_arg=(--notes-file "$NOTES_FILE")
  gh release create "v$VERSION" "$ZIP_NAME" "$DSYM_ZIP" \
    --title "Trimmy $VERSION" \
    --notes "Automated release $VERSION" \
    "${notes_arg[@]:-}" --draft=false --verify-tag
}

verify_downloads() {
  LOG "Verifying enclosure URL"
  curl -I "https://github.com/steipete/Trimmy/releases/download/v${VERSION}/Trimmy-${VERSION}.zip" | head -n 5
  LOG "Verifying dSYM URL"
  curl -I "https://github.com/steipete/Trimmy/releases/download/v${VERSION}/Trimmy-${VERSION}.dSYM.zip" | head -n 5
  LOG "Appcast head:"
  curl -s https://raw.githubusercontent.com/steipete/Trimmy/main/appcast.xml | head -n 15
}

update_file_versions
update_changelog_header
run_quality_gates
build_and_notarize
zip_dsym
sign_zip
update_appcast
create_tag_and_release
verify_downloads

LOG "Release $VERSION (build $BUILD) completed."
