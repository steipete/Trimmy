---
summary: "SwiftUI Settings window recipe for Trimmy with toolbar tabs and grouped forms."
read_when:
  - Modifying settings UI or Preferences window behavior
  - Adding new settings panes or controls
---

# SwiftUI-native Preferences Window (macOS 15+)

Goal: ship a real macOS Settings window (⌘,) using only SwiftUI—no custom AppKit controllers. You get toolbar-style tabs, grouped two-column rows, and modern window behavior out of the box.

## Current Trimmy organization
- **General**: auto-trim, optional automatic text reflow and leading-blank removal (both default off), manual reflow visibility, launch and menu-bar behavior.
- **Trimming**: regular-app and terminal sensitivity, live preview.
- **Rules**: app/site auto-trim exclusions and preserved URL query parameters.
- **Shortcuts**: global paste and auto-trim shortcuts.
- **Advanced**: low-frequency text cleanup, clipboard compatibility, CLI installer, development tools.
- **About**: version, links, license, and update controls.

Use `SettingsPaneLayout`, `SettingsSection`, and `SettingsTextEditor` for new controls so spacing, scrolling, and editor treatment remain consistent. Keep sections flat and native; do not add custom card backgrounds.

## 1) Wire the Settings scene
```swift
@main
struct TrimmyApp: App {
    var body: some Scene {
        MenuBarExtra("Trimmy", systemImage: "scissors") { /* … */ }

        Settings {
            SettingsRootView()
                .scenePadding()
        }
        .defaultSize(width: 560, height: 360)
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
    }
}
```
- SwiftUI auto-creates a single Settings window, wires App ▸ Settings… and ⌘, to it, and manages reuse.
- Use `NSApp.setActivationPolicy(.accessory)` for LSUIElement menu bar apps so windows can appear without a Dock icon.

## 2) Preference-style tabs with `TabView`
```swift
enum SettingsTab: Hashable { case general, shortcuts, updates }

struct SettingsRootView: View {
    @State private var selection: SettingsTab = .general

    var body: some View {
        TabView(selection: $selection) {
            GeneralSettingsPane()
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            HotkeySettingsPane()
                .tabItem { Label("Shortcuts", systemImage: "command") }
                .tag(SettingsTab.shortcuts)

            UpdateSettingsPane()
                .tabItem { Label("Updates", systemImage: "arrow.triangle.2.circlepath") }
                .tag(SettingsTab.updates)
        }
        // no extra padding; scenePadding covers it
    }
}
```
In a `Settings` scene, `TabView` renders as the classic toolbar tabs: centered SF Symbols, active underline, title follows the tab—just like Safari/Xcode.

## 3) Two-column rows via `Form` + `.formStyle(.grouped)` and `LabeledContent`
```swift
struct GeneralSettingsPane: View {
    @AppStorage("generalAggressiveness") private var generalAggressiveness: GeneralAggressiveness = .low
    @AppStorage("terminalAggressiveness") private var terminalAggressiveness: Aggressiveness = .normal
    @AppStorage("autoTrimEnabled") private var autoTrimEnabled = true
    @AppStorage("preserveBlankLines") private var preserveBlankLines = false
    @AppStorage("removeBoxDrawing") private var removeBoxDrawing = true
    @AppStorage("launchAtLogin") private var launchAtLogin = false

    var body: some View {
        Form {
            LabeledContent("General apps") {
                Picker("", selection: $generalAggressiveness) {
                    ForEach(GeneralAggressiveness.allCases) { Text($0.title).tag($0) }
                }
            }
            LabeledContent("Terminals") {
                Picker("", selection: $terminalAggressiveness) {
                    ForEach(Aggressiveness.allCases) { Text($0.title).tag($0) }
                }
            }

            LabeledContent("Auto-trim") { Toggle("", isOn: $autoTrimEnabled) }
            LabeledContent("Keep blank lines") { Toggle("", isOn: $preserveBlankLines) }
            LabeledContent("Remove box drawing chars (│┃)") { Toggle("", isOn: $removeBoxDrawing) }
            LabeledContent("Launch at login") { Toggle("", isOn: $launchAtLogin) }
        }
        .formStyle(.grouped)
    }
}
```
Why this feels native: `LabeledContent` supplies the left label/right control grid; empty toggle labels avoid duplicated text; grouped `Form` matches macOS System Settings per WWDC24 guidance.

## 4) Shortcuts pane
```swift
struct HotkeySettingsPane: View {
    @AppStorage("trimHotkeyEnabled") private var pasteTrimmedHotkeyEnabled = true
    @AppStorage("pasteOriginalHotkeyEnabled") private var pasteOriginalHotkeyEnabled = false

    var body: some View {
        Form {
            LabeledContent("Enable global “Paste Trimmed” hotkey") {
                Toggle("", isOn: $pasteTrimmedHotkeyEnabled)
            }
            KeyboardShortcuts.Recorder("Shortcut", name: .pasteTrimmed)

            LabeledContent("Enable global “Paste Original” hotkey") {
                Toggle("", isOn: $pasteOriginalHotkeyEnabled)
            }
            KeyboardShortcuts.Recorder("Shortcut", name: .pasteOriginal)
        }
        .formStyle(.grouped)
    }
}
```

## 5) Updates pane
```swift
struct UpdateSettingsPane: View {
    weak var updater: UpdaterProviding?

    var body: some View {
        Form {
            if let updater {
                LabeledContent("Automatically check for updates") {
                    Toggle("", isOn: Binding(
                        get: { updater.automaticallyChecksForUpdates },
                        set: {
                            updater.automaticallyChecksForUpdates = $0
                            updater.automaticallyDownloadsUpdates = $0
                        })
                    )
                }
                Button("Check for Updates…") { updater.checkForUpdates(nil) }
            } else {
                Text("Updates unavailable in this build.").foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }
}
```

## 6) Making it appear from a menu-bar app
- In `applicationDidFinishLaunching`, call `NSApp.setActivationPolicy(.accessory)` so windows can show without a Dock icon.
- In your menu UI, inject `@Environment(\.openSettings)` and call `NSApp.activate(ignoringOtherApps: true); openSettings()` for the “Settings…” item.

## 7) Window polish from WWDC24-10148
- `.defaultSize(width:height:)` for first-launch sizing.
- `.windowResizability(.contentSize)` to bound resizing to your content.
- `.windowStyle(.titleBar)` (or `.hiddenTitleBar`) to match the look you want.
- `.scenePadding()` to give grouped forms breathing room.

## 8) When to reach for AppKit
Most apps don’t need it. SwiftUI’s `Settings` scene + `TabView` + grouped `Form` deliver:
- Toolbar tabs with icons/title syncing
- Single-instance Settings window bound to ⌘,
- Native two-column rows, dark mode, hover states
If you later need custom placements, borderless windows, or fine-grained toolbar tweaks, you can layer AppKit on top—but start with pure SwiftUI.

## 9) Accessibility permission callout
- When `AXIsProcessTrusted()` is false, show an inline callout in the General tab with buttons that trigger the system Accessibility prompt (`AXIsProcessTrustedWithOptions`) and deep-link to Privacy & Security → Accessibility.
- Mirror the callout in the menu bar popover so users understand why “Paste Trimmed/Original” does nothing until permission is granted.
