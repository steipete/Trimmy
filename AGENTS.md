# Repository Guidelines

## Project Structure & Module Organization
- `Sources/Trimmy`: Swift 6 macOS menu-bar app (clipboard watcher, command detector, settings panes; entry `TrimmyApp.swift`).
- `Sources/TrimmyCore`: shared text cleanup; `Sources/TrimmyCLI`: headless executable.
- `Tests/TrimmyCoreTests` and `Tests/TrimmyCLITests`: portable Swift Testing suites. `Tests/TrimmyTests` covers macOS clipboard and UI integration.
- `Scripts`: helper shell scripts; prefer them over ad-hoc build/run/sign steps.
- `docs/`: contributor notes and website. Keep `CHANGELOG.md` Trimmy-only. SwiftPM is the build definition; open `Package.swift` in Xcode. Assets, `Info*.plist`, icons, and `appcast.xml` live at the root.

## Build, Test, and Development Commands
- `./Scripts/compile_and_run.sh` — build, test, package, and launch the signed dev app; run after code changes.
- `swift build` / `swift build -c release` — package builds for macOS 15+/Swift 6.2.
- `./Scripts/package_app.sh [debug|release]` — produce `Trimmy.app`; run before validation.
- `./Scripts/sign-and-notarize.sh` — ship-ready signing + notarization.
- `swift test [--filter …]` — executes the Swift Testing suites.
- `swiftformat .` then `swiftlint lint --fix` (or `swiftlint lint`) — enforce formatting and linting.
- After any code change, run `pnpm check` and fix all reported format/lint issues before handoff.

## Coding Style & Naming Conventions
- SwiftFormat config: 4-space indent, LF, max width 120, before-first wrapping for args/params, explicit `self` inserted for concurrency correctness.
- SwiftLint: analyzer checks for unused code/imports; warnings on `force_cast`/`force_try`; file length warning at 1500 lines—extract helpers early.
- Follow existing names like `Settings*Pane`, `*Monitor`, `CommandDetector`; favor small, focused types and functions.

## Testing Guidelines
- Add Swift Testing suites with `@Suite`/`@Test` and `#expect` in the target that owns the behavior; pure text tests belong in `TrimmyCoreTests`.
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
- Releases must only be performed when explicitly requested in the current prompt; permission is one-time and does not persist to future sessions.

# Building Trimmy
- Preferred workflow: run `Scripts/compile_and_run.sh` after code changes. It stops running instances, builds and tests the package, packages a debug app, and relaunches the menu bar app. Debug packaging reuses SwiftPM build outputs; release packaging starts with `swift package clean`.
- Use `Scripts/package_app.sh release` + `Scripts/sign-and-notarize.sh` only when preparing a signed release build.
- Preserve the spring tab-selection animation in `SettingsView` and the window dimensions in `SettingsTab`.
