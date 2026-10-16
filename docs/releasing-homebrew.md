---
summary: "Trimmy Homebrew cask publication and verification."
read_when:
  - Verifying a Trimmy release in Homebrew
  - Updating the CI Homebrew handoff
---

# Homebrew (Trimmy)

The [release workflow](../.github/workflows/release.yml) updates `steipete/homebrew-tap/Casks/trimmy.rb` after publishing the signed and notarized app. It uses `HOMEBREW_TAP_TOKEN`, takes the checksum from the verified release payload, and preserves the arm64/macOS 15 requirements. Dry runs never write the tap.

See [the release process](release.md) to prepare or rehearse a release. No separate local tap commit is needed. Verify the published cask version and SHA-256 against `SHA256SUMS` on the GitHub Release; if the handoff fails, repair it using the retained verified payload without rebuilding or moving the tag.
