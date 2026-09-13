---
summary: "Debug clipboard behavior with focused tests, signed app runs, and unified logging."
read_when:
  - Investigating clipboard transformations or pasteboard ownership
  - Debugging Trimmy from a terminal or Xcode
---

# Debugging clipboard behavior

Build and launch the signed development app from the checkout:

```sh
./Scripts/compile_and_run.sh
log stream --level debug --predicate 'subsystem == "com.steipete.trimmy"'
```

Clipboard logs report pasteboard change counts, source-app context, selected sensitivity, skip reasons and text lengths. Preserve the user's clipboard and settings when exercising synthetic copies.

Use focused Swift Testing suites for reproducible inputs:

```sh
swift test --filter TextCleanerTests
swift test --filter ClipboardMonitorTests
swift test --filter MarkdownReformatterTests
```

For breakpoints, open `Package.swift` in Xcode and debug the relevant test. The transformation boundary is `TextCleaner.transform`; app-specific reflow and sensitivity selection live in `ClipboardMonitor.transform`. Manual paste actions enter `pasteTrimmed`, `pasteOriginal`, `pasteReformattedMarkdown`, or `pasteStrippingURLQueryParams` before `performPaste`.

Debug builds also expose **Advanced → Enable debug tools**, which reveals the Debug tab's sample-preview and trim-animation buttons. There is no global `DebugHooks` object; use these controls or a focused test to drive the current code.
