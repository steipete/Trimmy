---
summary: "LLDB/tmux script to drive Trimmy headlessly and inspect clipboard paths."
read_when:
  - Debugging Trimmy without UI access (remote/ssh)
  - Investigating clipboard trimming behavior interactively
---

# Trimmy LLDB Drive-by Debugging

Use this when you can’t click the UI (e.g., remote session) but need to exercise menu actions and inspect state end-to-end.

## One-shot script (start, drive, inspect)
```bash
# from repo root
tmux new -s trimdebug -d 'cd /Users/steipete/Projects/Trimmy && lldb .build/debug/Trimmy'
tmux send-keys -t trimdebug "run" C-m
# wait for menu to appear, then interrupt
tmux send-keys -t trimdebug "process interrupt" C-m
# drive Trimmy without UI clicks
tmux send-keys -t trimdebug "expr -l Swift -- import AppKit; import Trimmy" C-m
tmux send-keys -t trimdebug "expr -l Swift -- _ = NSPasteboard.general.setString(\"echo test\\\\nls -l\", forType: .string)" C-m
tmux send-keys -t trimdebug "expr -l Swift -- Trimmy.DebugHooks.hotkeyManager?.pasteTrimmedNow()" C-m
tmux send-keys -t trimdebug "expr -l Swift -- Trimmy.DebugHooks.monitor?.lastSummary" C-m
# when finished
tmux send-keys -t trimdebug "quit" C-m
tmux kill-session -t trimdebug
pkill -f \"Trimmy.app/Contents/MacOS/Trimmy\" || true
```

## What the commands do
- `DebugHooks.hotkeyManager?.pasteTrimmedNow()` calls the same path as the “Paste Trimmed” button/hotkey (force trim at High + summary update).
- `DebugHooks.monitor?.lastSummary` reads the string shown under “Last:” in the menu.
- You can clear/reset with `DebugHooks.monitor?.lastSummary = ""` if needed.

## Breakpoints to inspect trimming
Inside LLDB:
```
breakpoint set --name Trimmy.ClipboardMonitor.trimClipboardIfNeeded
breakpoint set --name Trimmy.ClipboardMonitor.readTextFromPasteboard
breakpoint set --name Trimmy.ClipboardMonitor.writeTrimmed
continue
```
Use `frame variable` and `bt` at stops to inspect flow; `force` should be `true` for manual trims.

## Reset/clean
Run `Scripts/compile_and_run.sh` to kill old instances, build, test, package, relaunch, and verify the app stays up. Always do this after code edits before debugging so you only have one Trimmy running.
