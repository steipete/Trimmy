#!/usr/bin/env bash
# Install an exact official release on the macOS and Ubuntu 24.04 CI runners.
set -euo pipefail
swift_version=${1:?usage: install_swift_ci.sh <major.minor[.patch]>}
swift_script_dir=$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)
: "${GITHUB_PATH:?This installer is for GitHub Actions}"
: "${GITHUB_ENV:?This installer is for GitHub Actions}"
: "${RUNNER_TEMP:?This installer is for GitHub Actions}"
[[ "$swift_version" =~ ^[0-9]+\.[0-9]+(\.[0-9]+)?$ ]] || { echo "Expected an exact Swift release version." >&2; exit 2; }
swift_release="swift-${swift_version}-RELEASE"
swift_url="https://download.swift.org/swift-${swift_version}-release"
swift_work=$(mktemp -d "$RUNNER_TEMP/trimmy-swift.XXXXXX")
trap 'rm -r "$swift_work"' EXIT

case "$(uname -s)" in
  Darwin)
    curl -fL --retry 3 "$swift_url/xcode/$swift_release/$swift_release-osx.pkg" -o "$swift_work/swift.pkg"
    swift_signature=$(pkgutil --check-signature "$swift_work/swift.pkg")
    printf '%s\n' "$swift_signature"
    if ! printf '%s\n' "$swift_signature" | grep -Eq \
      '^[[:space:]]*1[.] Developer ID Installer: Swift Open Source [(]V9AUD2URP3[)]$'; then
      echo "Unexpected Swift package signing identity." >&2
      exit 1
    fi
    sudo installer -pkg "$swift_work/swift.pkg" -target /
    swift_bin="/Library/Developer/Toolchains/$swift_release.xctoolchain/usr/bin"
    echo "TOOLCHAINS=$swift_release" >> "$GITHUB_ENV"
    ;;
  Linux)
    [[ "$(uname -m)" == "x86_64" ]] || { echo "Expected an x86_64 Ubuntu runner." >&2; exit 2; }
    curl -fL --retry 3 "$swift_url/ubuntu2404/$swift_release/$swift_release-ubuntu24.04.tar.gz" \
      -o "$swift_work/swift.tar.gz"
    curl -fL --retry 3 "$swift_url/ubuntu2404/$swift_release/$swift_release-ubuntu24.04.tar.gz.sig" \
      -o "$swift_work/swift.tar.gz.sig"
    mkdir -m 700 "$swift_work/gnupg"
    gpg --batch --homedir "$swift_work/gnupg" --import "$swift_script_dir/swift-release-key.asc"
    gpg --batch --homedir "$swift_work/gnupg" --verify "$swift_work/swift.tar.gz.sig" "$swift_work/swift.tar.gz"
    swift_root="$RUNNER_TEMP/$swift_release"
    mkdir -p "$swift_root"
    tar -xzf "$swift_work/swift.tar.gz" --strip-components=1 -C "$swift_root"
    swift_bin="$swift_root/usr/bin"
    ;;
  *) echo "Unsupported CI operating system." >&2; exit 2 ;;
esac

swift_version_output=$("$swift_bin/swift" --version)
printf '%s\n' "$swift_version_output"
swift_short_version="$swift_version"
if [[ "$swift_version" == *.*.0 ]]; then
  swift_short_version="${swift_version%.0}"
fi
case "$swift_version_output" in
  *"Swift version $swift_version ("*|*"Swift version $swift_short_version ("*) ;;
  *) echo "Installed Swift does not match the requested version." >&2; exit 1 ;;
esac
echo "$swift_bin" >> "$GITHUB_PATH"
