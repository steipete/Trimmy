---
summary: "Trimmy repo guardrails, build/lint/test commands, and release expectations."
read_when:
  - Starting work on Trimmy
  - Before running builds, tests, or changing tooling
---

# Repository Guidelines

## Project Structure & Module Organization
- `Sources/Trimmy`: SwiftUI/macOS app code (clipboard monitoring, command detection, settings panes, telemetry, entry point `TrimmyApp.swift`).
- `Tests/TrimmyTests`: XCTest suites covering clipboard behavior, aggressiveness previews, and edge-case pasteboard handling.
- `Scripts`: automation helpers; prefer these over ad-hoc commands. `compile_and_run.sh` for day-to-day dev, `package_app.sh` for release bundles, `sign-and-notarize.sh` for distribution.
- `docs`: contributor docs (this file and feature notes). Keep `CHANGELOG.md` Trimmy-only.
- Assets and project metadata live at repository root (`Trimmy.xcodeproj`, `Info.plist`, icons, Sparkle feed `appcast.xml`).

## Build, Test, and Development Commands
- Dev build & launch: `./Scripts/compile_and_run.sh` (re-run after code changes; avoids launching stale app bundles).
- Swift build: `swift build` (debug) or `swift build -c release` for production binaries.
- Package app: `./Scripts/package_app.sh release` → `Trimmy.app`; follow with `./Scripts/sign-and-notarize.sh` when shipping.
- Tests: `swift test` (use `--filter` to target a suite). Run before push/PR.
- Format & lint: `swiftformat .` then `swiftlint lint --fix` (or `swiftlint lint`). Fix reported issues before committing.

## Coding Style & Naming Conventions
- SwiftFormat config: 4-space indent, LF line endings, max width 120, arguments/parameters wrapped before-first, explicit `self` inserted for Swift 6 concurrency. Do not hand-format differently.
- SwiftLint config favors strictness: keep imports sorted by formatter, avoid force casts/tries (warnings), respect length thresholds, and leave single-letter identifiers only when local. Analyzer rules flag unused code.
- Prefer small, focused types and functions; extract helpers instead of letting files grow past soft limits (file warning 1500 lines).
- Use descriptive names for settings panes and clipboard helpers; follow existing `Settings*Pane` and `*Monitor` patterns.

## Testing Guidelines
- Add/extend XCTest cases under `Tests/TrimmyTests`; mirror naming like `ClipboardMonitorTests` and `AggressivenessPreviewExamplesTests`.
- Cover new clipboard parsing branches and regression fixes with explicit inputs/expected outputs; favor deterministic tests over UI snapshots.
- Maintain or increase coverage; do not skip `swift test` in CI-equivalent workflows.

## Commit & Pull Request Guidelines
- Commit messages: short, imperative, and scoped (e.g., “Fix Sparkle feed URL”, “Add settings height animation guard”).
- Before opening a PR: run `swiftformat .`, `swiftlint lint --fix`, `swift test`, and `./Scripts/compile_and_run.sh` to verify the app boots cleanly.
- Include a concise summary, linked issue (if applicable), repro steps, and before/after notes or screenshots for UI-touching changes.
- Update `CHANGELOG.md` for user-visible adjustments; keep entries Trimmy-specific. Avoid introducing new tooling or dependencies without prior approval.

## Release & Maintenance Notes
- Follow the release checklist from `README.md` (format/lint/test, package, sign/notarize, stapler validation).
- Do not edit bundled artifacts directly; regenerate via scripts. Preserve per-tab settings animations (`contentHeight`/`preferredHeight`) when touching settings views.
