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
APP_BUNDLE="Trimmy.app"

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
require python3

[[ -z "${APP_STORE_CONNECT_API_KEY_P8:-}" || -z "${APP_STORE_CONNECT_KEY_ID:-}" || -z "${APP_STORE_CONNECT_ISSUER_ID:-}" ]] && \
  ERR "APP_STORE_CONNECT_* env vars must be set."
[[ -z "${SPARKLE_PRIVATE_KEY_FILE:-}" ]] && ERR "SPARKLE_PRIVATE_KEY_FILE must be set."
[[ -f "$SPARKLE_PRIVATE_KEY_FILE" ]] || ERR "SPARKLE_PRIVATE_KEY_FILE not found at $SPARKLE_PRIVATE_KEY_FILE"

git diff --quiet || ERR "Working tree is not clean."

# Pre-flight: ensure changelog is finalized and release not already present
./Scripts/validate_changelog.sh "$VERSION"

get_appcast_head() {
  python3 - <<'PY'
import xml.etree.ElementTree as ET
root = ET.parse('appcast.xml').getroot()
channel = root.find('channel')
first = channel.find('item') if channel is not None else None
if first is None:
    raise SystemExit('appcast.xml has no <item> entries')
ns = {'sparkle': 'http://www.andymatuschak.org/xml-namespaces/sparkle'}
ver = first.findtext('sparkle:shortVersionString', namespaces=ns)
build = first.findtext('sparkle:version', namespaces=ns)
print(ver or '')
print(build or '')
PY
}
read_appcast_head() {
  local parts
  parts=($(get_appcast_head))
  APPCAST_TOP_VERSION=${parts[0]:-0.0.0}
  APPCAST_TOP_BUILD=${parts[1]:-0}
}

read_appcast_head
[[ "$APPCAST_TOP_VERSION" == "$VERSION" ]] && ERR "appcast already has version $VERSION; bump version first."
if [[ "$BUILD" -le ${APPCAST_TOP_BUILD:-0} ]]; then
  ERR "build number $BUILD must be greater than latest appcast build ${APPCAST_TOP_BUILD:-?}."
fi

# Quick Sparkle key sanity check
tmp_sparkle=/tmp/trimmy-sparkle-probe.txt
echo test > "$tmp_sparkle"
sign_update --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" -p "$tmp_sparkle" >/dev/null
rm -f "$tmp_sparkle"

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
     rf"\g<1>{ver}")
repl(pathlib.Path("Scripts/package_app.sh"),
     r'(CFBundleVersion</key><string>)([^<]+)',
     rf"\g<1>{build}")
repl(pathlib.Path("Scripts/sign-and-notarize.sh"),
     r'^(ZIP_NAME=)"Trimmy-[^"]+\.zip"$',
     rf'\g<1>"Trimmy-{ver}.zip"')
repl(pathlib.Path("version.env"),
     r'^(MARKETING_VERSION=).*$',
     rf'\g<1>{ver}')
repl(pathlib.Path("version.env"),
     r'^(BUILD_NUMBER=).*$',
     rf'\g<1>{build}')
repl(pathlib.Path("Info.plist"),
     r'(CFBundleShortVersionString</key>\s*<string>)([^<]+)',
     rf'\g<1>{ver}')
repl(pathlib.Path("Info.plist"),
     r'(CFBundleVersion</key>\s*<string>)([^<]+)',
     rf'\g<1>{build}')
repl(pathlib.Path("Info.debug.plist"),
     r'(CFBundleShortVersionString</key>\s*<string>)([^<]+)',
     rf'\g<1>{ver}')
repl(pathlib.Path("Info.debug.plist"),
     r'(CFBundleVersion</key>\s*<string>)([^<]+)',
     rf'\g<1>{build}')
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

extract_notes() {
  LOG "Extracting release notes from CHANGELOG.md"
  NOTES_PATH=$(mktemp /tmp/trimmy-notes-XXXX.md)
  python3 - "$VERSION" "$NOTES_PATH" <<'PY' || ERR "Failed to extract notes"
import sys, pathlib, re
version = sys.argv[1]
out = pathlib.Path(sys.argv[2])
text = pathlib.Path("CHANGELOG.md").read_text()
pattern = re.compile(rf"^##\s+{re.escape(version)}\s+—\s+.*$", re.M)
m = pattern.search(text)
if not m:
    raise SystemExit("section not found")
start = m.end()
next_header = text.find("\n## ", start)
chunk = text[start: next_header if next_header != -1 else len(text)]
lines = [ln for ln in chunk.strip().splitlines() if ln.strip()]
out.write_text("\n".join(lines) + "\n")
print(out)
PY
  NOTES_FILE="$NOTES_PATH"
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

verify_local_artifacts() {
  LOG "Verifying local artifacts in parallel"
  (
    sign_update --verify --ed-key-file "$SPARKLE_PRIVATE_KEY_FILE" "$ZIP_NAME" "$SIGNATURE" >/dev/null && LOG "Signature verify ok"
  ) &
  p1=$!
  (
    spctl -a -t exec -vv "$APP_BUNDLE" >/dev/null && LOG "spctl ok"
  ) &
  p2=$!
  (
    codesign --verify --deep --strict --verbose "$APP_BUNDLE" >/dev/null && LOG "codesign ok"
  ) &
  p3=$!
  local status=0
  for pid in $p1 $p2 $p3; do
    wait "$pid" || status=$?
  done
  [[ $status -eq 0 ]] || ERR "Local verification failed"
}

verify_remote_assets() {
  LOG "Verifying uploaded assets (HEAD)"
  (
    curl -I -L "https://github.com/steipete/Trimmy/releases/download/v${VERSION}/Trimmy-${VERSION}.zip" | head -n 5
  ) & p1=$!
  (
    curl -I -L "https://github.com/steipete/Trimmy/releases/download/v${VERSION}/Trimmy-${VERSION}.dSYM.zip" | head -n 5
  ) & p2=$!
  local status=0
  for pid in $p1 $p2; do
    wait "$pid" || status=$?
  done
  [[ $status -eq 0 ]] || ERR "Remote asset HEAD check failed"
}

create_tag_and_release() {
  LOG "Creating tag v$VERSION"
  git add CHANGELOG.md Scripts/package_app.sh Scripts/sign-and-notarize.sh appcast.xml \
    version.env Info.plist Info.debug.plist
  git commit -m "Release $VERSION (build $BUILD)"
  git tag "v$VERSION"
  LOG "Pushing main and tag"
  git push origin main
  git push origin "v$VERSION"

  LOG "Uploading artifacts to GitHub release"
  local notes_arg=()
  if [[ -n "$NOTES_FILE" ]]; then
    notes_arg=(--notes-file "$NOTES_FILE")
  else
    ERR "Notes file missing after extraction"
  fi
  gh release create "v$VERSION" "$ZIP_NAME" "$DSYM_ZIP" \
    --title "Trimmy $VERSION" \
    "${notes_arg[@]}" --draft=false --verify-tag
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
verify_local_artifacts
extract_notes
update_appcast
create_tag_and_release
verify_remote_assets
./Scripts/check-release-assets.sh "v$VERSION"
verify_downloads

LOG "Release $VERSION (build $BUILD) completed."
