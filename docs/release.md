---
summary: "Trimmy release checklist: package, sign, notarize, Sparkle appcast, and assets."
read_when:
  - Cutting or validating a Trimmy release
  - Updating appcast or signing/notarization steps
---

# Release process (Trimmy)

SwiftPM only; manual package/sign/notarize. Sparkle feed served from GitHub Releases.

**Must read first:** open the master macOS release guide at `~/Projects/agent-scripts/docs/RELEASING-MAC.md` alongside this file and reconcile any differences in favor of Trimmy specifics before starting a release.

## Expectations
- When asked to “release” a version, execute the full, end-to-end flow: bump versions/CHANGELOG, build, sign & notarize, upload the zip to the GitHub release, generate/update the appcast with the new signature, publish the release/tag, and verify the enclosure downloads successfully via HTTP (no 404s) and installs.
- If the version is shipped via Homebrew, update the tap cask too (see `docs/releasing-homebrew.md`).

### Release automation notes (Scripts/release.sh)
- Always forces a fresh rebuild/notarization (no cached artifacts) to avoid stale Swift outputs.
- Fails fast if: Xcode Info.plists are stale vs `version.env`, working tree is dirty, changelog top section is still “Unreleased”, target version already exists in appcast, or build number is not greater than the latest appcast build.
- Extracts release notes directly from the current changelog section and uses them for the GitHub release (no manual notes flag needed).
- Sparkle appcast notes are generated as HTML from the same changelog section and embedded into the appcast entry.
- Preflight Sparkle key sanity check; verifies signature, spctl, and codesign locally, and HEAD checks remote zip/dSYM; runs `Scripts/check-release-assets.sh v<ver>` after upload.
- Requires `python3`, `sign_update`, `generate_keys`, `generate_appcast`, `swiftlint`, `swift`, `gh`, `zip`, `curl` in PATH plus `APP_STORE_CONNECT_*`. `SPARKLE_PRIVATE_KEY_FILE` is only needed when overriding the default Keychain Sparkle key.

## Prereqs
- Xcode 26+ installed at `/Applications/Xcode.app` (for ictool/iconutil and SDKs).
- Developer ID Application cert installed: `Developer ID Application: Peter Steinberger (Y5PE65HELJ)`.
- ASC API creds in env: `APP_STORE_CONNECT_API_KEY_P8`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`.
- Sparkle keys: public key expectation lives in `.mac-release.env`; Trimmy still uses the older shared AGCY key, so the manifest includes the local Dropbox fallback path. `SPARKLE_PRIVATE_KEY_FILE` overrides it.
- Shared release helper: `Scripts/mac-release` resolves `MAC_RELEASE_TOOL`, sibling `../agent-scripts`, or `~/Projects/agent-scripts`.
- Sparkle auto-checks are **enabled by default** for release builds (set in `package_app.sh`); leave this on so update checks run without user toggles.

## Icon
If the .icon changes:
```
./Scripts/build_icon.sh Icon.icon Trimmy
```
Uses ictool/iconutil to produce Icon.icns.

## Build, sign, notarize (arm64)
```
./Scripts/sign-and-notarize.sh
```
What it does:
- `swift build -c release --arch arm64`
- Packages `Trimmy.app` with Info.plist and Icon.icns
- Embeds Sparkle.framework, Updater, Autoupdate, XPCs
- Codesigns **everything** with runtime + timestamp (deep) and adds rpath
- Zips to `Trimmy-<version>.zip`
- Submits to notarytool, waits, staples, validates

Gotchas fixed:
- Sparkle needs signing for framework, Autoupdate, Updater, XPCs (Downloader/Installer) or notarization fails.
- Use `--timestamp` and `--deep` when signing the app to avoid invalid signature errors.
- Avoid `unzip` when installing locally; prefer `ditto -x -k Trimmy-<ver>.zip /Applications` to prevent AppleDouble `._*` files that can break the signature.
- Manual sanity check before upload: `find Trimmy.app -name '._*'` should return nothing, then `spctl --assess --type execute --verbose Trimmy.app` and `codesign --verify --deep --strict --verbose Trimmy.app` should pass on the packaged bundle.

## Appcast (Sparkle)
After notarization, or let `Scripts/release.sh` do this:
```
./Scripts/make_appcast.sh Trimmy-<ver>.zip \
  https://raw.githubusercontent.com/steipete/Trimmy/main/appcast.xml
```
Generates HTML release notes from `CHANGELOG.md` (via `Scripts/changelog-to-html.sh`) and embeds them into the appcast entry.
Uploads not handled automatically—commit/publish appcast + zip to the feed location (GitHub Releases/raw URL).

## Tag & release
```
./Scripts/release.sh
```

## Checklist (quick)
- [ ] Read both this file and `~/Projects/agent-scripts/docs/RELEASING-MAC.md`; resolve any conflicts toward Trimmy’s specifics.
- [ ] Update `version.env`, the standalone version fallback in `Sources/TrimmyCLI/main.swift`, and CHANGELOG; run `Scripts/sync-version-plists.sh`. `Scripts/release.sh` pulls release notes from the top changelog section automatically, so finalize it first.
- [ ] `swiftformat .`, `swiftlint lint`, `swift test` (ensure zero warnings/errors)
- [ ] Confirm CI is green for the release commit (`gh run list/view`; rerun/fix until green).
- [ ] `./Scripts/build_icon.sh` if icon changed
- [ ] `./Scripts/sign-and-notarize.sh`
- [ ] Generate Sparkle appcast via `Scripts/release.sh` or `Scripts/make_appcast.sh`; use `SPARKLE_PRIVATE_KEY_FILE` only if overriding Keychain signing.
- [ ] Upload zip + appcast **and the Trimmy-<ver>.dSYM.zip** to the GitHub release; publish release/tag
  - Run `Scripts/check-release-assets.sh <tag>` after publishing to ensure both zip and dSYM are attached.
- [ ] Version continuity: confirm the new version is the immediate next patch/minor (no gaps) and CHANGELOG has no skipped numbers (e.g., after 0.2.0 use 0.2.1, not 0.2.2)
- [ ] Changelog sanity: single top-level title, no duplicate version sections, versions strictly descending with no repeats
- [ ] Release pages: title format `Trimmy <version>`, notes as Markdown list (no stray blank lines)
- [ ] Changelog/release notes are user-facing: avoid internal-only bullets (build numbers, script bumps) and keep entries concise
- [ ] Verify the release asset: download the uploaded `Trimmy-<ver>.zip`, unzip, run, and confirm code signature stubs in place (spctl + launch).
- [ ] Confirm `appcast.xml` is updated to the new version and points to the uploaded zip (no stale version/URL); HTML release notes should render (not escaped tags).
- [ ] Manually visit the enclosure URL (curl -I) to ensure 200/OK (no 404) after publishing assets/release
- [ ] Ensure `sparkle:edSignature` is present for the enclosure in appcast (generated by `generate_appcast` with the ed25519 key)
- [ ] When creating the GitHub release, paste the CHANGELOG entry as a proper Markdown list (one `-` per line, blank line between sections); verify the rendered release notes aren’t collapsed into a single line.
- [ ] After publishing, open the GitHub release page and visually confirm bullets render correctly (no literal `\n`, no duplicated/merged entries); fix via “Edit release” if anything is off.
- [ ] Post-publish housekeeping: bump `CHANGELOG.md` by moving the shipped notes under the released version, incrementing its patch number, and add a new `Unreleased` section for the next iteration.
- [ ] Keep an older signed build in `/Applications/Trimmy.app` (e.g., previous version) to manually verify Sparkle delta/full update to the new release.
- [ ] Preserve the dSYM: keep `Trimmy-<ver>.dSYM.zip` attached to the release for crash symbolication.
- [ ] For Sparkle verification: if replacing `/Applications/Trimmy.app`, first quit Trimmy, then replace the app bundle, and relaunch from `/Applications`. If a previous version is already installed there, leave it and just use it to test the update path.
- [ ] Manual Gatekeeper sanity: after packaging, `find Trimmy.app -name '._*'` is empty, `spctl --assess --type execute --verbose Trimmy.app` and `codesign --verify --deep --strict --verbose Trimmy.app` succeed
- **Definition of “done” for a release:** all of the above are complete, the appcast/enclosure link resolves with the right signature, and a previous public build can update to the new one via Sparkle. Anything short of that is not a finished release.

## Troubleshooting
- **Notarization invalid / app “damaged”**: repackage/sign with script; when installing locally use `ditto` to avoid `._*` files; verify with `spctl -a -t exec -vv Trimmy.app` and `stapler validate`.
- **Feed not updating**: ensure GitHub release asset URL in appcast matches the published version and is reachable (no 404).
- **About links missing**: confirm credits string construction in `Trimmy.swift` shows the inline links.
