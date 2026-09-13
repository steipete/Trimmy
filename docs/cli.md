---
summary: "Headless CLI for trimming text without launching the UI"
read_when:
  - Using Trimmy in scripts or CI
  - Trimming text via stdin or files without the menu bar app
---

# Trimmy CLI

`TrimmyCLI` is a headless trimmer that uses the same heuristics as the app. It reads from a file or stdin and writes the trimmed text to stdout (or JSON).

## Usage

```sh
swift run TrimmyCLI --trim /path/to/file
pbpaste | swift run TrimmyCLI --trim -
```

Or install the packaged helper from the app: Settings → Advanced → “Install CLI”, which symlinks the bundled helper to `/usr/local/bin/trimmy` and `/opt/homebrew/bin/trimmy`. Then you can run `trimmy --help`.

## Options
- `--trim <file>`: input file (use `-` or omit to read stdin)
- `--force, -f`: force High aggressiveness
- `--aggressiveness {low|normal|high}`
- `--preserve-blank-lines` / `--no-preserve-blank-lines`
- `--remove-box-drawing` / `--keep-box-drawing`
- `--json`: emit `{original, trimmed, transformed}`
- `--version, -v`: print Trimmy CLI version
- `--help, -h`: show help

## Exit codes
- `0`: success
- `1`: no input / read error
- `2`: no transformation applied
- `3`: JSON encoding error

## Examples

Trim a file:
```sh
swift run TrimmyCLI --trim scripts/setup.sh --aggressiveness normal
```

Trim stdin, force High aggressiveness, emit JSON:
```sh
pbpaste | swift run TrimmyCLI --trim - --force --json
```

Keep blank lines but strip box-drawing:
```sh
swift run TrimmyCLI --trim notes.txt --preserve-blank-lines --remove-box-drawing
```
