# Release process (Trimmy)

SwiftPM only; manual package/sign/notarize. Sparkle feed served from GitHub Releases.

## Prereqs
- Xcode 26+ installed at `/Applications/Xcode.app` (for ictool/iconutil and SDKs).
- Developer ID Application cert installed: `Developer ID Application: Peter Steinberger (Y5PE65HELJ)`.
- ASC API creds in env: `APP_STORE_CONNECT_API_KEY_P8`, `APP_STORE_CONNECT_KEY_ID`, `APP_STORE_CONNECT_ISSUER_ID`.
- Sparkle keys: public key already in Info.plist; private key path set via `SPARKLE_PRIVATE_KEY_FILE` when generating appcast.

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

## Appcast (Sparkle)
After notarization:
```
SPARKLE_PRIVATE_KEY_FILE=/path/to/ed25519-priv.key \
./Scripts/make_appcast.sh Trimmy-<ver>.zip \
  https://raw.githubusercontent.com/steipete/Trimmy/main/appcast.xml
```
Uploads not handled automatically—commit/publish appcast + zip to the feed location (GitHub Releases/raw URL).

## Tag & release
```
git tag v0.2.2
./Scripts/make_appcast.sh ...
# upload zip + appcast to Releases
# then create GitHub release (gh release create v0.1.1 ...)
```

## Checklist (quick)
- [ ] Update versions (Package scripts, About text, CHANGELOG)
- [ ] `swiftformat`, `swiftlint`, `swift test` (ensure zero warnings/errors)
- [ ] `./Scripts/build_icon.sh` if icon changed
- [ ] `./Scripts/sign-and-notarize.sh`
- [ ] Generate Sparkle appcast with private key
- [ ] Upload zip + appcast to feed, publish release/tag
- [ ] Verify the release asset: download the uploaded `Trimmy-<ver>.zip`, unzip, run, and confirm code signature stubs in place (spctl + launch).
- [ ] Confirm `appcast.xml` is updated to the new version and points to the uploaded zip (no stale version/URL).
- [ ] When creating the GitHub release, paste the CHANGELOG entry as a proper Markdown list (one `-` per line, blank line between sections); verify the rendered release notes aren’t collapsed into a single line.
- [ ] After publishing, open the GitHub release page and visually confirm bullets render correctly (no literal `\n`, no duplicated/merged entries); fix via “Edit release” if anything is off.
- [ ] Keep an older signed build in `/Applications/Trimmy.app` (e.g., previous version) to manually verify Sparkle delta/full update to the new release.
- [ ] For Sparkle verification: if replacing `/Applications/Trimmy.app`, first quit Trimmy, then replace the app bundle, and relaunch from `/Applications`. If a previous version is already installed there, leave it and just use it to test the update path.

## Troubleshooting
- **Notarization invalid / app “damaged”**: repackage/sign with script; when installing locally use `ditto` to avoid `._*` files; verify with `spctl -a -t exec -vv Trimmy.app` and `stapler validate`.
- **Feed not updating**: ensure GitHub release asset URL in appcast matches the published version and is reachable (no 404).
- **About links missing**: confirm credits string construction in `Trimmy.swift` shows the inline links.
