# Changelog

## 0.6.3 — Unreleased
- CI: publish Linux `TrimmyCLI` release assets (`.tar.gz` + `.sha256`) so Linux users can install without building from source.
- Thanks to @JaviSoto for contributing the workflow.

## 0.6.2 — 2025-12-17
- Box-drawing cleanup now skips when no box glyphs are present, preserving JSON/YAML indentation and spacing (thanks @ahmedasmar).
- TrimmyCLI now writes errors via `FileHandle.standardError` to satisfy Swift 6/Linux concurrency checks while keeping the same stderr output and exit codes (thanks @JaviSoto).
- Trimmy is now available via Homebrew: `brew install --cask steipete/tap/trimmy` (updates via `brew upgrade --cask steipete/tap/trimmy`).

## 0.6.1 — 2025-12-05
- Command detection now keeps multi-line command blocks intact when there are three or more standalone command-looking lines and no explicit joiners (\, |, &&, ||, ;); pipelines/continuations still flatten as before.
- Align app and CLI heuristics so both respect the above guard; CLI High/manual overrides still flatten.
- Added regression tests covering structured JSON copies and the pyenv init snippet to prevent unintended flattening in Normal mode.

## 0.6.0 — 2025-12-04

- Added in-app Accessibility permission prompts and menu/settings callouts so “Paste Trimmed/Original” explains how to enable ⌘V injection when permission is missing.
- Added CLI installer in Settings → General that symlinks the bundled TrimmyCLI into /usr/local/bin and /opt/homebrew/bin as `trimmy`.

## 0.5.1 — 2025-12-02
- Auto-trim (Low/Normal) now skips list-like snippets (bullets, numbered rows, plain token/ID columns) and copies with more than four newlines to avoid mangling hashes/IDs; High/manual override still flattens on demand. Regression tests cover the list/id scenarios.

## 0.5.0 — 2025-12-02
- Added headless CLI (`TrimmyCLI`) with `--trim` flag, sharing the same heuristics; supports stdin, json output, aggressiveness/blank-line/box-drawing options.
- Fixed strike-through preview: removed decorative pipes (│) now strike correctly, whitespace deletions show as struck dots, and truncation no longer hides removed characters.

## 0.4.7 — 2025-12-02
- Packaging: SwiftPM resource bundles are now symlinked to the app root so `KeyboardShortcuts`’ `Bundle.module` resolves in user builds (prevents Settings → Shortcuts crash).

## 0.4.6 — 2025-12-02
- Further tightened box-glyph cleanup so terminal-wrapped URLs (e.g., `releases/ │ download/...`) rejoin correctly without extra spaces.

## 0.4.5 — 2025-12-02
- Menu previews now show up to 100 characters (both trimmed and original) while keeping per-row truncation badges aligned with the longer limit.
- Paste Original row now shows only character count (no “trimmed” badge); trimmed badge remains on Paste Trimmed.
- Box-drawing cleanup: strip decorative “│” after real pipes and even when copied alone; added regression coverage for terminal-style decorations.

## 0.4.4 — 2025-12-01
- Fixed a crash when opening Settings → Shortcuts by ensuring the KeyboardShortcuts resource bundle is packaged into Trimmy.app; packaging now fails if SwiftPM bundles are missing and a regression test guards bundle availability.

## 0.4.3 — 2025-11-26
- Clipboard flattening now rejoins hyphen-wrapped tokens (e.g., `...-9bd2-\nf1a4...png`) without inserting spaces, fixing QR/path copies from chats.
- Guarded against treating markdown bullet lists as hyphen continuations so list snippets don’t get glued together when flattened.

## 0.4.2 — 2025-11-25
- Menu “Paste Trimmed” and “Paste Original” previews now share the same 50-character middle ellipsis and badge stats for consistent clipping.
- Settings window is slightly taller so previews and tabs fit without clipping.
- Debug builds now show a clear “DEBUG BUILD” marker in About to distinguish dev builds from releases.

## 0.4.1 — 2025-11-24
- Hardened command detection (#4): Low/Normal now skip when multi-line text looks like source code (brace + language keywords across Swift/JS/Go/Rust/Java/C#/Python, etc.) unless strong command cues are present. High/manual override still flattens on demand, so “Paste Trimmed” keeps working for power users.
- Strip prompt markers (#3): Copies that start with `#`/`$` are de-promoted when they look like shell commands (Markdown headings stay), so blog/chat snippets paste cleanly. Preferences/README now document aggressiveness levels with concrete before/after examples.
- Wrapped URLs are repaired automatically, even on Low aggressiveness, so line-breaks or stray spaces inside links (e.g., GitHub changelog URLs) no longer break the pasted URL.

## 0.4.0 — 2025-11-21
- Added “Paste Trimmed” action + global hotkey that trims on-the-fly (High aggressiveness), pastes, and restores your clipboard.
- Added “Paste Original” action + hotkey so you can paste the untouched copy even after auto-trim; Trimmy now keeps the untrimmed text around for that path.
- Paste actions now show the destination app (e.g., “Paste Trimmed to Ghostty”) so you know where the keystroke will land.
- Last preview now renders the original line with strike-through on removed characters for a quick diff-at-a-glance.
- Each paste action now shows its own preview: trimmed text under “Paste Trimmed” and struck-out original under “Paste Original.”
- Auto-Trim toggle moved below the divider to keep primary actions grouped at the top of the menu.
- Box-drawing stripping now handles any number of leading/trailing gutter bars (│┃ etc., most-line majority) while leaving real pipeline `|` characters intact; more regression tests cover single-line, majority, and both-sides cases, and previews mirror the runtime cleaner.

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
