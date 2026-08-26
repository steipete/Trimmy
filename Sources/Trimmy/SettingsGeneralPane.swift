import AppKit
import SwiftUI

@MainActor
struct GeneralSettingsPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissions: AccessibilityPermissionManager

    var body: some View {
        SettingsPaneLayout {
            if !self.permissions.isTrusted {
                AccessibilityPermissionCallout(permissions: self.permissions)
            }

            SettingsSection(
                "Automatic trimming",
                subtitle: "The main clipboard watcher. Manual paste actions remain available when this is off.")
            {
                PreferenceToggleRow(
                    title: "Enable auto-trim",
                    subtitle: "Automatically clean clipboard content using the enabled trimming rules.",
                    binding: self.$settings.autoTrimEnabled)
            }

            SettingsSection(
                "Text reflow",
                subtitle: "Join hard-wrapped prose and Markdown while preserving document structure.")
            {
                VStack(alignment: .leading, spacing: 16) {
                    PreferenceToggleRow(
                        title: "Automatically reflow copied text",
                        subtitle: "Apply text reflow as part of Auto-Trim, without using the menu action.",
                        binding: self.$settings.autoReflowTextEnabled)
                        .disabled(!self.settings.autoTrimEnabled)

                    Divider()

                    PreferenceToggleRow(
                        title: "Remove leading blank lines",
                        subtitle: "Strip empty or whitespace-only lines before the first paragraph when reflowing.",
                        binding: self.$settings.trimLeadingBlankLinesOnReflow)

                    Divider()

                    PreferenceToggleRow(
                        title: "Show manual reflow action",
                        subtitle: "Show “Paste Reflowed Text” in the Trimmy menu when reflowable text is copied.",
                        binding: self.$settings.showMarkdownReformatOption)
                }
            }

            SettingsSection(
                "App",
                subtitle: "Control how Trimmy starts and appears on your Mac.")
            {
                VStack(alignment: .leading, spacing: 16) {
                    PreferenceToggleRow(
                        title: "Hide menu bar icon",
                        subtitle: "Keep Trimmy running without showing its scissors icon.",
                        binding: self.$settings.hideMenuBarIcon)

                    Divider()

                    PreferenceToggleRow(
                        title: "Start at Login",
                        subtitle: "Launch Trimmy automatically when you sign in.",
                        binding: self.$settings.launchAtLogin)

                    Divider()

                    HStack {
                        Text("Stop the clipboard watcher and quit the app.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Button("Quit Trimmy") {
                            NSApp.terminate(nil)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
    }
}
