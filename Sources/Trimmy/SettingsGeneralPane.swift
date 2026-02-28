import AppKit
import SwiftUI
import TrimmyCore

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
                title: "Remove box drawing chars",
                subtitle: "Strip prompt-style box gutters (any count, leading/trailing) before trimming.",
                binding: self.$settings.removeBoxDrawing)

            if self.settings.removeBoxDrawing {
                HStack(alignment: .top, spacing: 8) {
                    Text("Chars:")
                        .foregroundStyle(.secondary)
                        .frame(width: 50, alignment: .trailing)
                    TextField("Box chars", text: self.$settings.boxDrawingChars)
                        .textFieldStyle(.roundedBorder)
                        .frame(maxWidth: 200)
                    Button("Reset") {
                        self.settings.boxDrawingChars = TrimConfig.defaultBoxDrawingChars
                    }
                    .buttonStyle(.borderless)
                }
                .padding(.leading, 28)
            }

            PreferenceToggleRow(
                title: "Clean path suffix",
                subtitle: "Remove trailing colon and line numbers from paths (e.g., /path/file.swift:42: → /path/file.swift).",
                binding: self.$settings.trimPathSuffix)

            PreferenceToggleRow(
                title: "Format heredoc blocks",
                subtitle: "Fix indentation and ensure EOF delimiter is at line start for shell heredoc syntax.",
                binding: self.$settings.formatHeredoc)

            PreferenceToggleRow(
                title: "Show Markdown reformat option",
                subtitle: "Expose a menu-only paste action that reflows markdown bullets and headings.",
                binding: self.$settings.showMarkdownReformatOption)

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
