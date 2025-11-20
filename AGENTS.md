# Repository Guidelines

READ ~/Projects/agent-scripts/{AGENTS.MD,TOOLS.MD} BEFORE ANYTHING (skip if files missing).

## Project Structure & Module Organization
- `Sources/Trimmy`: Swift 6 macOS menu-bar app (clipboard watcher, command detector, settings panes; entry `TrimmyApp.swift`).
- `Tests/TrimmyTests`: Swift Testing suites (e.g., `ClipboardMonitorTests`, `AggressivenessPreviewExamplesTests`) covering heuristics and pasteboard safety.
- `Scripts`: helper shell scripts; prefer them over ad-hoc build/run/sign steps.
- `docs/`: contributor notes (spec, release, prefs). Keep `CHANGELOG.md` Trimmy-only. Assets and project files live at the root (`Trimmy.xcodeproj`, `Info*.plist`, icons, `appcast.xml`).

## Build, Test, and Development Commands
- `./Scripts/compile_and_run.sh` — clean rebuild and launch the dev app; run after code changes to avoid stale bundles.
- `swift build` / `swift build -c release` — package builds for macOS 15+/Swift 6.2.
- `./Scripts/package_app.sh [debug|release]` — produce `Trimmy.app`; run before validation.
- `./Scripts/sign-and-notarize.sh` — ship-ready signing + notarization.
- `swift test [--filter …]` — executes Swift Testing/XCTest suite.
- `swiftformat .` then `swiftlint lint --fix` (or `swiftlint lint`) — enforce formatting and linting.

## Coding Style & Naming Conventions
- SwiftFormat config: 4-space indent, LF, max width 120, before-first wrapping for args/params, explicit `self` inserted for concurrency correctness.
- SwiftLint: analyzer checks for unused code/imports; warnings on `force_cast`/`force_try`; file length warning at 1500 lines—extract helpers early.
- Follow existing names like `Settings*Pane`, `*Monitor`, `CommandDetector`; favor small, focused types and functions.

## Testing Guidelines
- Tests live in `Tests/TrimmyTests`; add Swift Testing suites with `@Suite`/`@Test` and `#expect`.
- Mirror current naming (`ClipboardMonitorTests`, `AggressivenessPreviewExamplesTests`) and cover new heuristics, pasteboard fallbacks, and regressions.
- Maintain or improve coverage; do not skip `swift test` before PRs.

## Commit & Pull Request Guidelines
- Commit style mirrors history: lowercase, scoped prefixes when useful (`docs:`, `refactor:`, `fix:`) and imperative summaries.
- Before a PR: run `swiftformat .`, `swiftlint lint --fix`, `swift test`, and `./Scripts/compile_and_run.sh`; refresh `Trimmy.app` from the new build.
- Update `CHANGELOG.md` for user-visible changes; include concise description, linked issue, and screenshots for UI tweaks.
- Avoid new dependencies/tooling without approval; keep edits focused and avoid duplicate files.

## Release & Validation Notes
- Package with `./Scripts/package_app.sh release`, sign/notarize via `./Scripts/sign-and-notarize.sh`, then verify (`spctl`, `stapler`) per README checklist.
- Do not edit generated bundles directly—regenerate via scripts. Preserve per-tab settings animation behavior when touching settings views.

# Building Trimmy
- Preferred workflow: run `Scripts/compile_and_run.sh` after code changes. It kills any running instance, runs build + tests, packages a debug app, and relaunches the menu bar app.
- Use `Scripts/package_app.sh release` + `Scripts/sign-and-notarize.sh` only when preparing a signed release build.
- Settings tabs once animated per tab (spring + `contentHeight`/`preferredHeight`); restore from pre-2025-11-19 ~18:40 commit if needed.
