# Changelog

## 0.1.0 — 2025-11-16
- Initial release of Trimmy (macOS 15+, menu-bar only).
- Auto-flattens multi-line shell commands copied to the clipboard; respects `\` continuations, collapses whitespace, optional blank-line preservation.
- Aggressiveness levels (Low/Normal/High) to tune detection strictness; manual “Trim Clipboard Now” override.
- Menu controls: Auto-Trim toggle, Keep blank lines toggle, Aggressiveness submenu, last-trim preview, Quit.
- Robust clipboard watcher: marker type to skip self-writes, grace delay for promised data, fast polling.
- Packaging scripts: app bundling, signing + notarization helper, shipped notarized `Trimmy-0.1.0.zip`.
