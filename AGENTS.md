# Agent Notes
- Spoken notifications use the macOS `say` command with the current system default voice (no custom voice specified). Keep this consistent for future announcements.
- Debug builds packaged via `Scripts/package_app.sh` invalidate signatures (install_name_tool). Before launching locally from the repo, re-sign ad-hoc with `codesign --deep --force --sign - Trimmy.app` and then `open -n Trimmy.app`.
- SwiftFormat is configured for Swift sources only; don't run it on plist/sh scripts.
- Before any release work, read `docs/release.md` and ensure the CHANGELOG is in reverse-chronological order (newest version at top, bullets ordered by user-facing impact).
- When publishing a GitHub release, make sure release notes keep Markdown list formatting (no literal `\n` joins); paste the changelog bullets cleanly.
