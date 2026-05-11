# Trimmy ✂️

> **Paste once, run once.** A tiny macOS menu-bar app that flattens those multi-line shell snippets you copy from blogs, READMEs, and ChatGPT — so they actually paste and run.

[![macOS 15+](https://img.shields.io/badge/macOS-15%2B-0d0c0a?style=flat-square)](https://www.apple.com/macos/)
[![License: MIT](https://img.shields.io/badge/license-MIT-c4391f?style=flat-square)](LICENSE)
[![Homebrew](https://img.shields.io/badge/homebrew-steipete%2Ftap%2Ftrimmy-c4391f?style=flat-square)](https://github.com/steipete/homebrew-tap)
[![Latest release](https://img.shields.io/github/v/release/steipete/Trimmy?style=flat-square&color=0d0c0a)](https://github.com/steipete/Trimmy/releases/latest)

![Trimmy menu showing Paste Trimmed and Paste Original to Ghostty](trimmy.png)

## Install

```sh
brew install --cask steipete/tap/trimmy
```

…or grab the signed `.zip` from [Releases](https://github.com/steipete/Trimmy/releases/latest).
Sparkle keeps it up-to-date automatically.

## What it does

You copy this:

```sh
kubectl get pods \
    -n kube-system \
    --selector='app=ingress' \
    -o json | jq '.items[].metadata.name'
```

Trimmy quietly rewrites your clipboard to this:

```sh
kubectl get pods -n kube-system --selector='app=ingress' -o json | jq '.items[].metadata.name'
```

You paste once, the shell runs once. No more `dquote>` prompts, no half-pasted commands, no “did you mean to run that as four separate commands?”

![Terminal example showing a wrapped command flattened into one line](term-example.png)

## Highlights

- **Lives in your menu bar.** No dock icon (`LSUIElement`). macOS 15 and later.
- **Knows when it's a command.** Pipes, redirects, backslash continuations, `$` / `#` prompt gutters — all read as command cues. Markdown headings stay intact.
- **Per-context aggressiveness.** Set the eagerness separately for general apps and terminals (Terminal, iTerm, Ghostty, Warp, kitty, WezTerm, Hyper, Alacritty).
- **Two hotkeys.** Global *Paste Trimmed* and *Paste Original* — with a preview that shows the target app and strikes through what was removed.
- **Reflows wrapped Markdown** as a separate menu action. Preserves fenced code, headings, and intentional blank lines.
- **Strips URL query params** as a separate menu action. Keeps per-domain content identity (YouTube `v`/`list`/`t`, GitHub `tab`, Figma `node-id`, etc.); the keeplist is editable in Settings.
- **Strips box-drawing gutters** (`│`, `┃`) so you can paste right out of fancy CLI tools.
- **Stays on your Mac.** No telemetry, no auth, no network calls except Sparkle's update check. MIT licensed.

![Markdown reformatting example](markdown-trimmed.jpg)

## Aggressiveness levels

Settable per-context. **Low** is conservative; **High** flattens almost anything that looks command-shaped (and is what *Paste Trimmed* always uses). The defaults are tuned to be useful but never destructive: a 10-line safety valve skips auto-flatten on big blobs.

| Level      | When it triggers                                              |
| ---------- | ------------------------------------------------------------- |
| **None**   | Off (general apps only).                                      |
| **Low**    | Strong cues required: pipes, redirects, `\` continuations.    |
| **Normal** | Typical multi-line commands with flags. Default in terminals. |
| **High**   | Almost anything command-shaped. Used by *Paste Trimmed*.      |

Prompt gutters get cleaned automatically, so `# brew install foo` becomes `brew install foo` while a Markdown heading like `# Release notes` is left alone.

<details>
<summary>Worked examples</summary>

**Low** — `\` line continuations get joined:

```sh
ls -la \
  | grep '^d' \
  > dirs.txt
# → ls -la | grep '^d' > dirs.txt
```

**Normal** — multi-line `kubectl` pipelines:

```sh
kubectl get pods \
  -n kube-system \
  | jq '.items[].metadata.name'
# → kubectl get pods -n kube-system | jq '.items[].metadata.name'
```

**High** — even commands without explicit continuations:

```sh
echo "hello"
print status
# → echo "hello" print status
```

</details>

## Headless CLI

There's a bundled CLI for scripts and pipelines:

```sh
pbpaste | swift run TrimmyCLI --trim - --force
swift run TrimmyCLI --trim ~/snippet.sh --aggressiveness high --json
```

Flags: `--aggressiveness {low|normal|high}`, `--force/-f` (forces High), `--preserve-blank-lines` / `--no-preserve-blank-lines`, `--remove-box-drawing` / `--keep-box-drawing`, `--json`.
Exit codes: `0` ok · `1` no input/error · `2` no transformation · `3` JSON encode error.

## Build from source

Swift 6, macOS 15+:

```sh
swift build -c release
./Scripts/package_app.sh release   # → Trimmy.app
```

Then run `Trimmy.app` (or add it to Login Items via the menu).

```sh
swiftformat .
swiftlint lint --fix
swift test
```

## How it works

- ~150 ms polling timer with an 80 ms grace delay so promised pasteboard data lands before Trimmy decides what to do.
- Clipboard writes carry a `com.steipete.trimmy` marker pasteboard type so Trimmy never reprocesses its own output.
- Sparkle handles auto-updates: auto-check, auto-download, then the menu shows *“Update ready, restart now?”*

## Related

- ✂️ [Trimmy](https://trimmy.app) — this repo.
- 🪶 [Alfred workflow](https://github.com/jimmystridh/alfred-trimmy) — community Alfred integration.
- 🟦🟩 [CodexBar](https://codexbar.app) — keep Codex token windows visible in the menu bar.
- 🧳 [MCPorter](https://mcporter.dev) — TypeScript toolkit + CLI for Model Context Protocol servers.
- 🧿 [Oracle](https://github.com/steipete/oracle) — multi-model prompt bundler/CLI.

## License

[MIT](LICENSE) — built by [Peter Steinberger](https://github.com/steipete) in Vienna, with help from a small pair of scissors.
