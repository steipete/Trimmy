# Trimmy ✂️ — Paste once, run once.

[![CI](https://img.shields.io/github/actions/workflow/status/steipete/Trimmy/ci.yml?branch=main&style=flat-square&label=ci)](https://github.com/steipete/Trimmy/actions/workflows/ci.yml)
[![Latest release](https://img.shields.io/github/v/release/steipete/Trimmy?style=flat-square)](https://github.com/steipete/Trimmy/releases/latest)
[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-0d0c0a?style=flat-square)](https://www.apple.com/macos/)
[![License](https://img.shields.io/github/license/steipete/Trimmy?style=flat-square)](LICENSE)
[![Homebrew](https://img.shields.io/badge/homebrew-steipete%2Ftap%2Ftrimmy-c4391f?style=flat-square)](https://github.com/steipete/homebrew-tap)

Trimmy is a macOS menu-bar app that turns copied multi-line shell snippets into one pasteable command. It watches the clipboard and uses command cues plus configurable sensitivity to avoid rewriting ordinary prose and code.

![Trimmy menu showing Paste Trimmed and Paste Original to Ghostty](trimmy.png)

```sh
printf '%s\n' \
  'Trimmy' \
  'is ready'
# clipboard → printf '%s\n' 'Trimmy' 'is ready'
```

Trimmy rewrites the copy once; your next paste is a single command.

## Install

On an Apple silicon Mac running macOS 15 or later:

```sh
brew install --cask steipete/tap/trimmy
```

You can instead download the signed app from [GitHub Releases](https://github.com/steipete/Trimmy/releases/latest). Sparkle checks for app updates after installation.

## Quick start

1. Open Trimmy. The scissors icon appears in the menu bar.
2. Copy the three-line `printf` command above.
3. Paste into a terminal. Trimmy has changed the clipboard to one line, so the shell runs it once and prints:

```text
Trimmy
is ready
```

The default sensitivity is Low in general apps and Normal in terminals. Use **Paste Original** from the menu whenever you need the untouched copy.

![Terminal example showing a wrapped command flattened into one line](term-example.png)

## Choose when Trimmy acts

Trimmy uses separate sensitivity settings for general apps and terminals. It recognizes Terminal, iTerm, Ghostty, Warp, kitty, WezTerm, Hyper, Alacritty, and cmux, and you can exclude specific apps or browser sites from automatic trimming.

| Level | Behavior |
| --- | --- |
| **None** | Disables command flattening in general apps; optional text reflow still applies. |
| **Low** | Requires strong cues such as pipes, redirects, or `\` continuations. |
| **Normal** | Handles typical multi-line commands with flags. This is the terminal default. |
| **High** | Flattens most command-shaped text. **Paste Trimmed** always uses this level. |

Prompt gutters such as `$` and `#` are removed when separated from a command by whitespace. Shell variable references such as `$HOME/bin/tool` and Markdown headings such as `# GitHub Actions` remain intact. Automatic trimming skips large clipboard blobs as a safety valve.

Low and Normal sensitivity preserve YAML block scalars and their required indentation. High sensitivity and manual **Paste Trimmed** still flatten on request.

## Paste actions and permissions

**Paste Trimmed** and **Paste Original** can be assigned global shortcuts. Clearing a shortcut keeps it unset after restarting Trimmy. Their menu previews name the target app and show what trimming removed before sending a paste keystroke. Manual pastes use the latest copy and temporarily replace the clipboard, then restore every available item and format unless another app has copied something newer.

These paste actions need macOS Accessibility permission. Trimmy prompts for it when necessary and links to **System Settings → Privacy & Security → Accessibility**. Automatic clipboard rewriting still works without simulated paste access.

## Other cleanup actions

Enable **Settings → General → Automatically reflow copied text** to join hard-wrapped prose and Markdown during Auto-Trim. It defaults off, respects app/site exclusions, and preserves headings, lists, paragraph breaks, and fenced code. Recognized source code and configuration are excluded. The manual **Paste Reflowed Text** action uses the same checks; optional removal of leading blank lines also defaults off. Recognized documents are reflowed before command cleanup so fenced examples stay intact. Closing fences require only trailing spaces or tabs, and numbered list markers require one to nine ASCII digits followed by a period or parenthesis and whitespace. A separate action removes URL query parameters while retaining configured identity parameters such as YouTube video IDs, GitHub tabs, and Figma node IDs.

Box-drawing gutters such as `│` and `┃` can also be removed from copied terminal output without stripping real shell pipes. Paths containing spaces are quoted for the shell while preserving literal dollar signs, backticks, backslashes, and quotes; a leading `~/` still expands to your home directory. Command continuations accept LF, CRLF, and CR line endings.

![Markdown reformatting example](markdown-trimmed.jpg)

## Headless CLI

`TrimmyCLI` uses the same trimming engine without the menu-bar app. Run it from the source checkout:

```sh
printf '%s\n' 'echo hello \' '  world' | swift run TrimmyCLI --trim --force
```

The result is `echo hello world`. The packaged app can install `trimmy` from **Settings → Advanced**, and Linux binaries are attached to [GitHub Releases](https://github.com/steipete/Trimmy/releases/latest).

See the [CLI reference](docs/cli.md) for file input, JSON output, all options, and exit codes.

## How it works

- A roughly 150 ms timer watches for pasteboard ownership changes, followed by an 80 ms grace period for promised clipboard data.
- Clipboard writes carry a `com.steipete.trimmy` marker so Trimmy does not process its own output.
- Clipboard content stays local. Trimmy has no telemetry or account system; its network use is Sparkle's update check.

The [technical specification](docs/spec.md) covers the detection heuristics, settings, and pasteboard behavior in more detail.

## Development

Trimmy requires Swift 6.3 and macOS 15 or later. Install a Swift 6.3 toolchain if your Xcode version bundles an older compiler.

`TrimmyCore` owns the shared text-cleaning pipeline. Its tests and the CLI tests run on macOS and Linux; `TrimmyTests` covers the macOS clipboard and UI integration. SwiftPM includes app dependencies only on macOS.

Open `Package.swift` in Xcode, or use the commands below. The build scripts select SwiftPM’s native backend to retain static Linux linking and the package layout on Swift 6.4. Debug packaging reuses the current SwiftPM build and signs a fresh app bundle; release packaging starts with a clean build.

CI covers Swift 6.3 and 6.4.0 on macOS and Linux, using SwiftFormat 0.63.0 and SwiftLint 0.65.1. `Scripts/install_lint_tools.sh <directory>` installs checksum-verified macOS lint binaries into a chosen directory.

`Scripts/install_swift_ci.sh` installs exact official Swift releases in CI. It requires the macOS package's signer to be Swift Open Source (`V9AUD2URP3`) and verifies Linux archives against the pinned public Swift release key (`52BB7E3DE28A71BE22EC05FFEF80A866B47A981F`, from [Swift's published keys](https://www.swift.org/keys/all-keys.asc)). Review the signing identity when updating toolchains to a release signed by a different key.

```sh
swift build --build-system native
swift test --build-system native
pnpm check
./Scripts/package_app.sh debug
```

## Related

- [trimmy.app](https://trimmy.app) is the project website.
- [Alfred Trimmy](https://github.com/jimmystridh/alfred-trimmy) is a community Alfred workflow.
- [CodexBar](https://codexbar.app) keeps Codex token windows visible in the menu bar.
- [MCPorter](https://mcporter.dev) is a TypeScript toolkit and CLI for Model Context Protocol servers.
- [Oracle](https://github.com/steipete/oracle) is a multi-model prompt bundler and CLI.

## License

[MIT](LICENSE) — built by [Peter Steinberger](https://github.com/steipete) in Vienna, with help from a small pair of scissors.
