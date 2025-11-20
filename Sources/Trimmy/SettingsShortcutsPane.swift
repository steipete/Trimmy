import KeyboardShortcuts
import SwiftUI

@MainActor
struct HotkeySettingsPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var hotkeyManager: HotkeyManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PreferenceToggleRow(
                title: "Enable global “Paste Trimmed” hotkey",
                subtitle: "Trim on-the-fly and paste without permanently changing the clipboard.",
                binding: self.$settings.pasteTrimmedHotkeyEnabled)

            VStack(alignment: .leading, spacing: 6) {
                KeyboardShortcuts.Recorder("", name: .pasteTrimmed)
                    .labelsHidden()
                    .opacity(self.settings.pasteTrimmedHotkeyEnabled ? 1.0 : 0.4)
                    .disabled(!self.settings.pasteTrimmedHotkeyEnabled)
                Text("Paste Trimmed always uses High aggressiveness and then restores your clipboard.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            PreferenceToggleRow(
                title: "Enable global “Paste Original” hotkey",
                subtitle: "Paste the unedited copy even if Trimmy already auto-trimmed it.",
                binding: self.$settings.pasteOriginalHotkeyEnabled)

            KeyboardShortcuts.Recorder("", name: .pasteOriginal)
                .labelsHidden()
                .opacity(self.settings.pasteOriginalHotkeyEnabled ? 1.0 : 0.4)
                .disabled(!self.settings.pasteOriginalHotkeyEnabled)

            PreferenceToggleRow(
                title: "Enable global Auto-Trim toggle hotkey",
                subtitle: "Quickly turn Auto-Trim on or off without opening the menu.",
                binding: self.$settings.autoTrimHotkeyEnabled)

            KeyboardShortcuts.Recorder("", name: .toggleAutoTrim)
                .labelsHidden()
                .opacity(self.settings.autoTrimHotkeyEnabled ? 1.0 : 0.4)
                .disabled(!self.settings.autoTrimHotkeyEnabled)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}
