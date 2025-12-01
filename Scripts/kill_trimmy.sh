#!/usr/bin/env bash
# Stop any running Trimmy instances (packaged or built artifacts).

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_PROCESS_PATTERN="Trimmy.app/Contents/MacOS/Trimmy"
DEBUG_PROCESS_PATTERN="${ROOT_DIR}/.build/debug/Trimmy"
RELEASE_PROCESS_PATTERN="${ROOT_DIR}/.build/release/Trimmy"

for _ in {1..10}; do
  pkill -f "${APP_PROCESS_PATTERN}" 2>/dev/null || true
  pkill -f "${DEBUG_PROCESS_PATTERN}" 2>/dev/null || true
  pkill -f "${RELEASE_PROCESS_PATTERN}" 2>/dev/null || true
  pkill -x "Trimmy" 2>/dev/null || true

  if ! pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1 \
     && ! pgrep -f "${DEBUG_PROCESS_PATTERN}" >/dev/null 2>&1 \
     && ! pgrep -f "${RELEASE_PROCESS_PATTERN}" >/dev/null 2>&1 \
     && ! pgrep -x "Trimmy" >/dev/null 2>&1; then
    exit 0
  fi

  sleep 0.3
done

echo "WARN: Could not stop all Trimmy instances" >&2
exit 1
