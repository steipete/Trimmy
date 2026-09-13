---
summary: "Manual signed-app verification with Peekaboo: menu, settings and synthetic clipboard copies."
read_when:
  - Verifying menu bar, settings, and clipboard behavior end to end
  - Testing packaged shortcut resources
---

# Manual app verification

Use the installed signed Peekaboo CLI. Check `peekaboo --version` and the current subcommand help; build Peekaboo only when working on Peekaboo itself.

Build and launch Trimmy with `Scripts/compile_and_run.sh`. Verify its signature with `codesign --verify --deep --strict Trimmy.app`. Save the user's clipboard and note any settings you will change before testing.

```sh
peekaboo permissions status --all-sources --json
peekaboo app list --include-background --json
peekaboo menu list --app Trimmy --json
peekaboo menu click --app Trimmy --item 'Settings…' --json
peekaboo window list --app Trimmy --json
```

Use the returned window ID for observation, and fresh element/snapshot IDs for each action:

```sh
peekaboo see --window-id <window-id> --annotate --path /tmp/trimmy-settings.png --json
peekaboo click --on <element-id> --snapshot <snapshot-id> --json
```

Verify these behaviors with synthetic text:

- Auto-Trim on joins `echo hello` followed by a backslash continuation and `| cat`; Auto-Trim off leaves it unchanged.
- Low and Normal preserve YAML scalar indentation, including shell examples inside the scalar.
- Keep blank lines retains paragraph separators when flattening a command.
- Remove box-drawing gutters removes decorative `│` while preserving real shell pipes.
- Paste Trimmed and Paste Original respect Accessibility permission and target the expected app.
- All settings tabs open, including Shortcuts. To verify packaged resources, quit the app, temporarily move this checkout's `.build` directory aside, and reopen the signed bundle before opening Shortcuts. Restore the build directory afterward.

Refresh observations after each action. Capture only the app window or synthetic content when recording proof. Restore the original clipboard representations and settings after the run. Record the date, tested commit, commands and outcome in the PR body.
