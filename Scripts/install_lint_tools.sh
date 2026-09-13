#!/usr/bin/env bash
# Install pinned macOS lint tools without changing the system tool installation.
set -euo pipefail
lint_bin_dir=${1:?usage: install_lint_tools.sh <directory>}
lint_work=$(mktemp -d)
trap 'rm -r "$lint_work"' EXIT
mkdir -p "$lint_bin_dir"

curl -fsSL https://github.com/nicklockwood/SwiftFormat/releases/download/0.63.0/swiftformat.zip \
  -o "$lint_work/swiftformat.zip"
printf '%s  %s\n' 28c7802e11fa5ae113d903066439c6bb1be20a8ac1ad9709c42616a7e273fb0f \
  "$lint_work/swiftformat.zip" | shasum -a 256 -c -
unzip -q "$lint_work/swiftformat.zip" -d "$lint_work/format"
install -m 755 "$lint_work/format/swiftformat" "$lint_bin_dir/swiftformat"

curl -fsSL https://github.com/realm/SwiftLint/releases/download/0.65.1/portable_swiftlint.zip \
  -o "$lint_work/swiftlint.zip"
printf '%s  %s\n' c1e429b0599cf1b516f369a2d9ec04eaf0e436f3c12b637df8851fa52ff694d0 \
  "$lint_work/swiftlint.zip" | shasum -a 256 -c -
unzip -q "$lint_work/swiftlint.zip" -d "$lint_work/lint"
install -m 755 "$lint_work/lint/swiftlint" "$lint_bin_dir/swiftlint"

"$lint_bin_dir/swiftformat" --version
"$lint_bin_dir/swiftlint" version
