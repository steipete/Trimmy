import AppKit
import SwiftUI

@MainActor
struct GeneralSettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PreferenceToggleRow(
                title: "Auto-trim enabled",
                subtitle: "Automatically trim clipboard content when it looks like a command.",
                binding: self.$settings.autoTrimEnabled)

            PreferenceToggleRow(
                title: "Keep blank lines",
                subtitle: "Preserve intentional blank lines instead of collapsing them.",
                binding: self.$settings.preserveBlankLines)

            PreferenceToggleRow(
                title: "Remove box drawing chars (│ │)",
                subtitle: "Strip prompt-style box borders before trimming.",
                binding: self.$settings.removeBoxDrawing)

            PreferenceToggleRow(
                title: "Use extra clipboard fallbacks",
                subtitle: "Try RTF and public text types when plain text is missing (helps apps that don’t expose UTF-8).",
                binding: self.$settings.usePasteboardFallbacks)

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
