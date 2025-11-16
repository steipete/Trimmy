# Trimmy ✂️
![Trimmy logo](trimmy-logo.png)

> "Paste once, run once." — Trimmy flattens those multi-line shell snippets you copy so they actually paste and run.

## What it does
- Lives in your macOS menu bar (macOS 15+). No Dock icon.
- Watches the clipboard and, when it looks like a shell command, removes newlines (respects `\` continuations) and rewrites the clipboard automatically.
- Aggressiveness levels (Low/Normal/High) to control how eagerly it detects commands:
  - **Low:** only flattens when it’s obviously a command. Example: a long `kubectl ... | jq ...` multi-line snippet.
  - **Normal (default):** balances caution and helpfulness. Example: a `brew update \ && brew upgrade` copy from a blog post.
  - **High:** flattens almost any multi-line text that *could* be a command. Example: a quick two-line `ls` + `cd` copied from chat.
- Optional "Keep blank lines" so scripts with intentional spacing stay readable.
- Manual "Trim Clipboard Now" button if you just want to force a flatten.
- Uses a marker pasteboard type to avoid reprocessing its own writes; polls with a lightweight timer and a small grace delay to catch promised pasteboard data.
- Safety valve: skips auto-flatten if the copy is more than 10 lines (even on High) to avoid mangling big blobs.\n

## Quick start
1. Build: `swift build -c release` (Swift 6, macOS 15+).
2. Bundle: `./Scripts/package_app.sh release` → `Trimmy.app`.
3. Launch: open `Trimmy.app` (or add to Login Items). Menu shows Auto-Trim toggle, Aggressiveness submenu, Keep blank lines toggle, Trim Now, and last-trim status.

## Lint / Format
- Format: `swiftformat .` (config `.swiftformat` from Peekaboo defaults).
- Lint: `swiftlint lint --fix` or `swiftlint lint` (config `.swiftlint.yml` from Peekaboo defaults).

## Notes
- Bundle ID: `com.steipete.trimmy` (LSUIElement menu-bar app).
- Polling: ~150ms with leeway; grace delay ~80ms to let promised data arrive.
- Clipboard writes tag themselves with `dev.peter.trimmy` to avoid loops.

## License
MIT
