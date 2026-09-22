#!/usr/bin/env bash
# Reset Trimmy: kill running instances, build, test, package, relaunch, verify.

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
APP_BUNDLE="${ROOT_DIR}/Trimmy.app"
APP_PROCESS_PATTERN="Trimmy.app/Contents/MacOS/Trimmy"

log()  { printf '%s\n' "$*"; }
fail() { printf 'ERROR: %s\n' "$*" >&2; exit 1; }

run_step() {
  local label="$1"; shift
  log "==> ${label}"
  if ! "$@"; then
    fail "${label} failed"
  fi
}

run_step "stop app" "${ROOT_DIR}/Scripts/kill_trimmy.sh"

# Tests build all package targets before packaging.
run_step "swift test" swift test --build-system native -q
run_step "package app" "${ROOT_DIR}/Scripts/package_app.sh" debug

run_step "launch app" open "${APP_BUNDLE}"

sleep 1
if pgrep -f "${APP_PROCESS_PATTERN}" >/dev/null 2>&1; then
  log "OK: Trimmy is running."
else
  fail "App exited immediately. Check crash logs in Console.app (User Reports)."
fi
