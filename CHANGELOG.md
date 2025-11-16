# Changelog

## 0.2.1 — 2025-11-16
- Moved the last-trim preview to sit directly beneath “Trim Clipboard Now” for a faster read.
- Bumped bundle version/build (0.2.1/5).

## 0.2.2 — 2025-11-16
- About panel now lists GitHub · Website · Twitter · Email links inline (matches CodexBar).

## 0.2.0 — 2025-11-16
- Sparkle auto-updates (Check for Updates…, auto-check toggle) with GitHub feed and signed appcast.
- Launch-at-login toggle (SMAppService) persisted and applied at startup.
- Clickable About panel (GitHub link) showing version/build.
- Strict concurrency + Swift Testing; lint/format configs aligned with other menu-bar apps.

## 0.1.3 — 2025-11-16
- Launch-at-login toggle (SMAppService) with persisted setting.
- Sparkle auto-updates (Check for Updates…, auto-check toggle, feed to GitHub Releases).
- Swift Testing migration; lint/format configs added; strict concurrency opt-in.
- Removed legacy XCTest suite; kept core detector tests.

## 0.1.2 — 2025-11-16
- Fix About panel credits: use attributed credits with version and icon so the About menu reliably appears.

## 0.1.1 — 2025-11-16
- Clipboard flattening now repairs accidental newlines inside tokens (e.g., `N\nODE_PATH` → `NODE_PATH`) to avoid inserting stray spaces when copying shell commands.
- Added safety valve: copies longer than 10 lines are skipped from auto-flattening, even on High aggressiveness.
- About dialog added (menu item) showing author (Peter Steinberger), MIT license, and GitHub link.

## 0.1.0 — 2025-11-16
- Initial release of Trimmy (macOS 15+, menu-bar only).
- Auto-flattens multi-line shell commands copied to the clipboard; respects `\` continuations, collapses whitespace, optional blank-line preservation.
- Aggressiveness levels (Low/Normal/High) to tune detection strictness; manual “Trim Clipboard Now” override.
- Menu controls: Auto-Trim toggle, Keep blank lines toggle, Aggressiveness submenu, last-trim preview, Quit.
- Robust clipboard watcher: marker type to skip self-writes, grace delay for promised data, fast polling.
- Packaging scripts: app bundling, signing + notarization helper, shipped notarized `Trimmy-0.1.0.zip`.
