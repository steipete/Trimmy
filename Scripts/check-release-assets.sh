#!/usr/bin/env bash
set -euo pipefail

if ! command -v gh >/dev/null 2>&1; then
  echo "gh CLI is required" >&2
  exit 1
fi

REPO=$(gh repo view --json nameWithOwner --jq .nameWithOwner)
TAG=${1:-$(git describe --tags --abbrev=0)}

assets=$(gh release view "$TAG" --repo "$REPO" --json assets --jq '.assets[].name')

zip_asset=$(printf "%s\n" "$assets" | grep -E 'Trimmy-[0-9.]+\.zip$' || true)
dsym_asset=$(printf "%s\n" "$assets" | grep -E 'Trimmy-[0-9.]+\.dSYM\.zip$' || true)

if [[ -z "$zip_asset" ]]; then
  echo "ERROR: app zip missing on release $TAG" >&2
  exit 1
fi

if [[ -z "$dsym_asset" ]]; then
  echo "ERROR: dSYM zip missing on release $TAG" >&2
  exit 1
fi

echo "Release $TAG has zip ($zip_asset) and dSYM ($dsym_asset)."
