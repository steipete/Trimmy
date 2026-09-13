---
summary: "Current settings structure, shared controls, window sizing, and tab routing."
read_when:
  - Modifying settings UI or window behavior
  - Adding a settings pane or control
---

# Settings window

`TrimmyApp` owns the SwiftUI `Settings` scene. `SettingsView` uses a `TabView` with a fixed size from `SettingsTab.windowWidth` and `windowHeight` (560 × 620), a content-sized window, and a spring animation when switching tabs. Pane content scrolls through `SettingsPaneLayout`.

| Tab | Contents |
| --- | --- |
| General | Auto-trim, automatic text reflow, leading-blank removal, manual reflow visibility, login launch and menu icon visibility |
| Trimming | General-app and terminal sensitivity, context-aware trimming, examples |
| Rules | App/site exclusions and preserved URL query parameters |
| Shortcuts | Paste Trimmed, Paste Original and Toggle Auto-Trim recorders |
| Advanced | Text cleanup options, pasteboard fallbacks, CLI installation and the debug-tools toggle |
| About | Version, build information, links and Sparkle update controls |
| Debug | Sample previews and trim animation; debug builds only, when enabled |

Use `SettingsSection`, `PreferenceToggleRow`, `SettingsTextEditor`, and `ShortcutSettingsRow` to keep new controls consistent. Preserve the current spacing and flat native presentation.

`AppSettings` owns persisted preferences. Keep existing storage keys when renaming properties, and maintain migrations for released settings. The app owns `HotkeyManager`; changing shortcut-enabled preferences refreshes registration through the settings callbacks.

Menu actions request a tab through `SettingsTabRouter`, activate the accessory app, call SwiftUI's `openSettings`, then post `trimmySelectSettingsTab`. Reopening the app requests General through `trimmyOpenSettings`. The pending route handles opening a window that is not yet visible.

Accessibility permission is shared by the app, menu, and General pane. `AccessibilityPermissionCallout` supplies the prompt and System Settings link. `UpdaterProviding` supplies update controls to About; unavailable updaters show their reason there.
