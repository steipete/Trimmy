#!/usr/bin/env bash
set -euo pipefail

ROOT=$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)
cd "$ROOT"

source "$ROOT/version.env"

check=0
if [[ "${1:-}" == "--check" ]]; then
  check=1
fi

python3 - "$MARKETING_VERSION" "$BUILD_NUMBER" "$check" <<'PY'
import plistlib
import re
import sys
from pathlib import Path

version, build, check = sys.argv[1], sys.argv[2], sys.argv[3] == "1"
paths = [Path("Info.plist"), Path("Info.debug.plist")]
dirty = []
cli_path = Path("Sources/TrimmyCLI/TrimmyCLI.swift")
cli_source = cli_path.read_text()
cli_pattern = r'(?m)^        return "([^"]+)"$'
cli_matches = list(re.finditer(cli_pattern, cli_source))
if len(cli_matches) != 1:
    raise SystemExit("Expected one CLI fallback version; update the version sync script for the new layout.")
cli_version = cli_matches[0].group(1)
cli_dirty = cli_version != version

for path in paths:
    data = plistlib.loads(path.read_bytes())
    before = (
        data.get("CFBundleShortVersionString"),
        data.get("CFBundleVersion"),
    )
    after = (version, build)
    if before != after:
        dirty.append((path, before, after))
        if not check:
            data["CFBundleShortVersionString"] = version
            data["CFBundleVersion"] = build
            path.write_bytes(plistlib.dumps(data, sort_keys=False))

if cli_dirty and not check:
    cli_path.write_text(re.sub(cli_pattern, f'        return "{version}"', cli_source))

if (dirty or cli_dirty) and check:
    for path, before, after in dirty:
        print(
            f"{path} has {before[0]} ({before[1]}), expected {after[0]} ({after[1]})",
            file=sys.stderr,
        )
    if cli_dirty:
        print(f"{cli_path} fallback is {cli_version}, expected {version}", file=sys.stderr)
    print("Run Scripts/sync-version-plists.sh and commit the result.", file=sys.stderr)
    raise SystemExit(1)
PY
