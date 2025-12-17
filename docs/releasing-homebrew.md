---
summary: "Trimmy Homebrew cask release playbook."
read_when:
  - Publishing a Trimmy release via Homebrew
  - Updating the Homebrew tap cask for Trimmy
---

# Homebrew (Trimmy)

Homebrew ships the UI app via Cask.

## Prereqs
- Homebrew installed.
- Access to the tap repo: `../homebrew-tap`.

## 1) Release Trimmy normally
Publish `Trimmy-<version>.zip` to GitHub Releases (follow `docs/release.md` / `Scripts/release.sh`).

## 2) Update the Homebrew tap cask
In `../homebrew-tap`, add/update `Casks/trimmy.rb`:
- `url` points to the GitHub release asset: `.../releases/download/v<version>/Trimmy-<version>.zip`
- Update `sha256` to match that zip.
- Keep `depends_on arch: :arm64` and `depends_on macos: ">= :sequoia"` (Trimmy is macOS 15+).

## 3) Verify install
```sh
brew uninstall --cask trimmy || true
brew untap steipete/tap || true
brew tap steipete/tap
brew install --cask steipete/tap/trimmy
open -a Trimmy
```

## 4) Push tap changes
Commit + push in the tap repo.
