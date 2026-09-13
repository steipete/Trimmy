import SwiftUI

@MainActor
struct AdvancedSettingsPane: View {
    @ObservedObject var settings: AppSettings
    @State private var isInstallingCLI = false
    @State private var cliStatus: String?

    var body: some View {
        SettingsPaneLayout {
            SettingsSection(
                "Text cleanup",
                subtitle: "Fine-tune what Trimmy removes while preparing clipboard text.")
            {
                VStack(alignment: .leading, spacing: 16) {
                    PreferenceToggleRow(
                        title: "Keep blank lines",
                        subtitle: "Preserve intentional paragraph breaks instead of collapsing them.",
                        binding: self.$settings.preserveBlankLines)

                    Divider()

                    PreferenceToggleRow(
                        title: "Remove box-drawing gutters",
                        subtitle: "Strip prompt-style │ and ┃ characters before trimming.",
                        binding: self.$settings.removeBoxDrawing)

                    Divider()

                    PreferenceToggleRow(
                        title: "Flatten Claude Code prompts",
                        subtitle: "Remove ❯ and ─── decoration and join wrapped Claude Code prompts.",
                        binding: self.$settings.flattenClaudeCodePrompts)
                }
            }

            SettingsSection(
                "Clipboard compatibility",
                subtitle: "Optional compatibility behavior for apps that publish unusual clipboard formats.")
            {
                PreferenceToggleRow(
                    title: "Use extra clipboard fallbacks",
                    subtitle: "Try RTF and public text types when plain text is missing.",
                    binding: self.$settings.usePasteboardFallbacks)
            }

            SettingsSection(
                "Command line",
                subtitle: "Install the bundled TrimmyCLI helper for scripts and shell pipelines.")
            {
                self.cliInstallerSection
            }

            #if DEBUG
            SettingsSection(
                "Developer",
                subtitle: "Development-only controls for local builds.")
            {
                PreferenceToggleRow(
                    title: "Enable debug tools",
                    subtitle: "Show the Debug tab for sample previews and dev-only controls.",
                    binding: self.$settings.debugPaneEnabled)
            }
            #endif
        }
    }

    private var cliInstallerSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Links `trimmy` into /usr/local/bin and /opt/homebrew/bin.")
                .font(.callout)
                .foregroundStyle(.secondary)

            HStack(spacing: 10) {
                Button {
                    Task { await self.installCLI() }
                } label: {
                    if self.isInstallingCLI {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("Install CLI")
                    }
                }
                .disabled(self.isInstallingCLI)

                if let status = self.cliStatus {
                    Text(status)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
        }
    }

    // MARK: - CLI installer

    private func installCLI() async {
        guard !self.isInstallingCLI else { return }
        self.isInstallingCLI = true
        defer { self.isInstallingCLI = false }

        let helperURL = Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/TrimmyCLI")
        self.cliStatus = await CLIInstaller.install(helperURL: helperURL)
    }
}
