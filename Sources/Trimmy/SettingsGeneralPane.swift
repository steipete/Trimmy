import AppKit
import SwiftUI

@MainActor
struct GeneralSettingsPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissions: AccessibilityPermissionManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            if !self.permissions.isTrusted {
                AccessibilityPermissionCallout(permissions: self.permissions)
            }
            PreferenceToggleRow(
                title: "Auto-trim enabled",
                subtitle: "Automatically trim clipboard content when it looks like a command.",
                binding: self.$settings.autoTrimEnabled)

            PreferenceToggleRow(
                title: "Context-aware trimming",
                subtitle: "Use the terminal-specific aggressiveness when a terminal is detected "
                    + "(Cmd-C + app snapshot).",
                binding: self.$settings.contextAwareTrimmingEnabled)

            PreferenceToggleRow(
                title: "Keep blank lines",
                subtitle: "Preserve intentional blank lines instead of collapsing them.",
                binding: self.$settings.preserveBlankLines)

            PreferenceToggleRow(
                title: "Remove box drawing chars (│┃)",
                subtitle: "Strip prompt-style box gutters (any count, leading/trailing) before trimming.",
                binding: self.$settings.removeBoxDrawing)

            PreferenceToggleRow(
                title: "Flatten Claude Code prompts",
                subtitle: "Strip terminal decoration (❯, ───) and flatten wrapped prompts from Claude Code.",
                binding: self.$settings.flattenClaudeCodePrompts)

            PreferenceToggleRow(
                title: "Show Markdown reformat option",
                subtitle: "Expose a menu-only paste action that reflows markdown bullets and headings.",
                binding: self.$settings.showMarkdownReformatOption)

            PreferenceToggleRow(
                title: "Hide menu bar icon",
                subtitle: "Keep Trimmy running without showing its scissors icon in the menu bar.",
                binding: self.$settings.hideMenuBarIcon)

            Divider()
                .padding(.vertical, 4)

            PreferenceToggleRow(
                title: "Start at Login",
                subtitle: "Automatically opens the app when you start your Mac.",
                binding: self.$settings.launchAtLogin)

            HStack {
                Spacer()
                Button("Quit Trimmy") {
                    NSApp.terminate(nil)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}
