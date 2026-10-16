---
summary: "Trimmy CI release pipeline, dry runs, signing, Sparkle, and Homebrew."
read_when:
  - Preparing or verifying a Trimmy release
  - Updating release infrastructure
---

# Release process (Trimmy)

[Release](../.github/workflows/release.yml) owns publication. Push an existing SSH-signed, annotated `vX.Y.Z` tag to run the pipeline, or dispatch it from protected `main` with that existing tag and `dry_run=false`. It never creates, moves, or overwrites a version tag. Local publishing through `Scripts/release.sh` and `Scripts/make_appcast.sh` has been retired.

## Rehearse without publishing

```sh
gh workflow run release.yml --ref main -f dry_run=true
```

A dispatch defaults to a dry run of the exact protected main head. It requires green push CI for that commit, builds every shipping artifact, signs and notarizes the app, verifies metadata, architecture, deployment targets and matching dSYM UUIDs, smokes the app, and signs/verifies a candidate Sparkle feed. It retains the complete checksummed payload as an Actions artifact. It creates no tag, GitHub Release, live appcast update, or tap commit. An Unreleased changelog section is allowed for this rehearsal.

## Prepare a release

Only release when explicitly requested. Set `version.env` and all version metadata, then finalize a nonempty `## X.Y.Z — YYYY-MM-DD` changelog section at the top. The date must not be in the future. Increment the build number beyond every published appcast entry. Merge and wait for green **push** CI on the exact commit before creating the signed annotated tag using an allowed signer in `.github/release-allowed-signers`.

The pipeline verifies that the tag resolves to a commit on protected main, checks the signature and version, and refuses any existing GitHub Release, including drafts. App packaging stays in `Scripts/sign-and-notarize.sh`; the CI job supplies an ephemeral personal Developer ID keychain and App Store Connect credentials. The app and dSYM archive names stay compatible with existing downloads.

All platform builds finish before publication. The publisher verifies uploaded draft bytes against the retained payload, publishes the GitHub Release with changelog notes and checksums, updates `main/appcast.xml`, and updates the Homebrew tap from those verified checksums. Existing installed clients keep their current Sparkle feed URL and public key.

Required repository secrets are `MACOS_SIGNING_P12`, `MACOS_SIGNING_P12_PASSWORD`, `ASC_KEY_ID`, `ASC_ISSUER_ID`, `ASC_PRIVATE_KEY_P8`, `SPARKLE_PRIVATE_KEY`, and `HOMEBREW_TAP_TOKEN`. The Sparkle private key must match the app's existing `SUPublicEDKey`; the signing certificate must be Peter's Developer ID Application identity. No npm package is published by this repository.

## Verify and recover

The release is complete only after the release assets, live appcast, and tap agree. The pipeline preserves a failed draft as a version reservation and never clobbers assets. If feed or tap handoff fails after publication, inspect the retained payload and repair that handoff from the verified bytes; do not rerun packaging or recreate the tag. After a successful release, open the next Unreleased changelog section.

Local read-only helpers remain: `Scripts/check-release-assets.sh`, `Scripts/verify_appcast.sh`, and `Scripts/generate-release-notes.sh` (where present). Local packaging and development scripts remain available, but publication belongs to CI. When installing a ZIP manually, use `ditto -x -k` or Finder to preserve the signed bundle and avoid AppleDouble files.

The app is arm64-only. The release also includes the Linux x86_64 CLI archive. `Scripts/sync-version-plists.sh --check` checks the local metadata before release preparation.
