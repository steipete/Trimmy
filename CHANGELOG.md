# Changelog

# Changelog

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
