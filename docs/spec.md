---
summary: "Trimmy product/technical spec: goals, heuristics, settings, and build notes."
read_when:
  - Planning or scoping new Trimmy features
  - Changing clipboard detection heuristics or settings behavior
  - Reviewing product scope or requirements
---

# Trimmy Specification (draft)

## Purpose
- macOS 15+ menu-bar utility that watches the pasteboard for copied terminal commands and automatically flattens line breaks to make commands pasteable in one go.
- Avoids mangling non-command text via heuristics and user-configurable aggressiveness for general apps and terminals.

## Functional Requirements
1. **Clipboard watcher** polls `NSPasteboard.general` via a GCD `DispatchSourceTimer` (~150ms, small leeway) to detect ownership changes promptly and rewrites text in-place when it detects shell-like multi-line content.
2. **Detection heuristics** score copied text based on:
   - Presence of newlines / backslash line continuations
   - Pipes/`&&`/`|` tokens
   - Prompt `$` prefixes
   - "Command-looking" leading tokens (incl. sudo)
   - All lines resembling command syntax
3. **Aggressiveness levels** (user setting):
   - General apps: None / Low / Normal / High (default: Low).
   - Terminals: Low / Normal / High (default: Normal).
   - Context-aware trimming applies the terminal level when a terminal app is detected.
4. **Blank-line handling** (checkbox): when enabled, empty lines are preserved during flattening; otherwise all newlines collapse to spaces.
5. **Auto-trim toggle**: enable/disable automatic rewrite without quitting the app; manual "Paste Trimmed" works regardless and does not permanently alter the clipboard.
6. **Self-write marker**: Trimmy writes an extra pasteboard type (`com.steipete.trimmy`) so subsequent polls can ignore its own writes and only react to user changes.
7. **Grace delay**: small (~80ms) deferred read after detecting a changeCount bump to allow promised/late pasteboard data to become available; skipped if changeCount moves again.
8. **Robust text read**: prefers `readObjects(forClasses:[NSString.self])`, falls back to common public text UTI types before declaring “no text”.
9. **UI**
   - Menu bar icon/text "Trimmy" with menu items: Auto-Trim toggle, "Paste Trimmed", "Paste Reflowed Text" (when wrapped prose or Markdown is detected), "Paste Original", status line showing last action preview, Quit.
   - General settings control automatic text reflow (default off), removal of leading blank lines during reflow (default off for compatibility), and visibility of the manual reflow paste action (default on).
   - SwiftUI Settings window (macOS-standard Settings scene) organized into General, Trimming, Rules, Shortcuts, Advanced, and About tabs.
   - Trimming contains sensitivity pickers for General apps and Terminals plus cleanup behavior.
   - Rules contains auto-trim app/site exclusions and URL content-identity parameter rules.
7. **Last action preview**: menu shows truncated (~70 chars) version of last trimmed command.
8. **Accessory app**: no Dock icon, lives in menu bar; quit from menu.
9. **Accessibility permission UX**: when Accessibility is missing, Trimmy blocks paste commands and shows actionable callouts (menu + Settings) to trigger the system prompt and open the Privacy & Security › Accessibility pane.
10. **CLI helper**: Settings → Advanced exposes an installer that symlinks the bundled helper into `/usr/local/bin` and `/opt/homebrew/bin` as `trimmy` for headless use.

## Non-Functional Requirements
- Platform: macOS 15.0+; Swift 6; SwiftUI for UI and settings; AppKit for pasteboard access.
- Performance: lightweight polling; avoid excessive CPU; operations on main actor for UI safety.
- Privacy: clipboard data stays local; no network usage.

## Build & Run
- Build: `swift build` (or `swift build -c release`).
- Run from CLI: `swift run &` or execute `.build/debug/Trimmy &`.
- Bundle as .app: run `Scripts/package_app.sh [debug|release]` → outputs `Trimmy.app` with `LSUIElement` set (menu-bar only). Copy to `/Applications` or Drag to Login Items for auto-start. Optional: add an SMLoginItem helper for automatic login launch.

## Open Items
- Add packaging script to emit a ready-to-install `.app` bundle and optional notarization pipeline.
- Optional notification/HUD when a trim occurs.
- Tune heuristics set; consider whitelist for file extensions or URLs.
