# Changelog

## Unreleased
- Added “Paste Trimmed” action + global hotkey that trims on-the-fly (High aggressiveness), pastes, and restores your clipboard.
- Added “Paste Original” action + hotkey so you can paste the untouched copy even after auto-trim; Trimmy now keeps the untrimmed text around for that path.

## 0.3.0 — 2025-11-20
- Preferences got the full SwiftUI treatment: toolbar tabs (General, Aggressiveness, Shortcuts, About), window auto-resizing per tab, and richer About content with dimmed update controls for debug builds.
- Shortcuts pane focuses on the Trim Clipboard hotkey (with glyphs) and lets you toggle or rebind it.
- Global “Trim Clipboard” shortcut ships with a default of ⌥⌘T; you can change or disable it in Settings → Shortcuts and it shows in the menu.
- New optional global hotkey lets you toggle Auto-Trim on/off without opening the menu (disabled by default; configurable in Shortcuts).
- Menu bar entry mirrors the new Settings window—actions for Trim Clipboard, Settings…, About Trimmy, plus a multi-line “Last” preview instead of the old submenu.
- Menu bar icon dims automatically when Auto-Trim is disabled so it’s obvious the service is paused.
- Trimmy now runs as a single instance to avoid double clipboard watchers or duplicate menu bar icons.
- Aggressiveness previews now ship with a more illustrative “Low” example and unit tests that lock behavior for all three levels.
- Manual “Trim Clipboard” and its global shortcut now always run at High aggressiveness, while auto-trim honors the configured level.
- New toggle (off by default) lets you enable extra clipboard fallbacks (RTF/public text types) for apps that don’t expose plain UTF-8 content.
- Clipboard flattening now stitches path segments split across lines (e.g. `~/.ssh/\ngithub_rsa.pub`) without inserting stray spaces; applies to auto-trim (your set aggressiveness), manual trim (High), and the Aggressiveness preview examples.
- Sparkle updater now auto-disables for unsigned/dev runs to avoid updater error dialogs during development.
- Debug builds now use bundle ID `com.steipete.trimmy.debug` and ship with Sparkle feed disabled, so Accessibility/Input Monitoring and updater prompts stay isolated from release builds.

## 0.2.4 — 2025-11-17
- Last trim preview now middle-truncates long text so the menu stays compact while showing both start and end of the command.
- Packaging/signing hardened: strip extended attributes, remove AppleDouble (`._*`) files, and re-sign Sparkle + app bundle to satisfy Gatekeeper and notarization.

## 0.2.3 — 2025-11-17
- Optional stripping of box-drawing separators (│ │) with whitespace collapse so prompt-style borders paste cleanly.
- Thanks to @Blueemi for contributing the box-drawing cleaning option.
- Quit item restored in the menu bar root (consistent with CodexBar layout).
- Release notes/process cleanup (archive/signing steps clarified).

## 0.2.2 — 2025-11-16
- About panel now lists GitHub · Website · Twitter · Email links inline (matches CodexBar).

## 0.2.1 — 2025-11-16
- Moved the last-trim preview to sit directly beneath “Trim Clipboard Now” for a faster read.
- Bumped bundle version/build (0.2.1/5).

## 0.2.0 — 2025-11-16
- Sparkle auto-updates (Check for Updates…, auto-check toggle) with GitHub feed and signed appcast.
- Launch-at-login toggle (SMAppService) persisted and applied at startup.
- Clickable About panel (GitHub link) showing version/build.
- Strict concurrency + Swift Testing; lint/format configs aligned with other menu-bar apps.

## 0.1.3 — 2025-11-16
- Launch-at-login toggle (SMAppService) with persisted setting.
- Sparkle auto-updates (Check for Updates…, auto-check toggle, feed to GitHub Releases).
- Lint/format configs aligned; strict concurrency opt-in.

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
