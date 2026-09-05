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
| **None** | Disables automatic trimming in general apps. |
| **Low** | Requires strong cues such as pipes, redirects, or `\` continuations. |
| **Normal** | Handles typical multi-line commands with flags. This is the terminal default. |
| **High** | Flattens most command-shaped text. **Paste Trimmed** always uses this level. |

Prompt gutters such as `$` and `#` are removed when they prefix a command, while Markdown headings remain intact. Automatic trimming skips large clipboard blobs as a safety valve.

Low and Normal sensitivity preserve YAML block scalars and their required indentation. High sensitivity and manual **Paste Trimmed** still flatten on request.

## Paste actions and permissions

**Paste Trimmed** and **Paste Original** can be assigned global shortcuts. Their menu previews name the target app and show what trimming removed before sending a paste keystroke.

These paste actions need macOS Accessibility permission. Trimmy prompts for it when necessary and links to **System Settings → Privacy & Security → Accessibility**. Automatic clipboard rewriting still works without simulated paste access.

## Other cleanup actions

The menu can reflow hard-wrapped Markdown while preserving headings, lists, blank lines, and fenced code. A separate action removes URL query parameters while retaining configured identity parameters such as YouTube video IDs, GitHub tabs, and Figma node IDs.

Box-drawing gutters such as `│` and `┃` can also be removed from copied terminal output without stripping real shell pipes.

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

Trimmy requires Swift 6.2 and macOS 15 or later.

```sh
swift build
swift test
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
