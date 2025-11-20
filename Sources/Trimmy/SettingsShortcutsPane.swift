import SwiftUI
import KeyboardShortcuts

@MainActor
struct HotkeySettingsPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var hotkeyManager: HotkeyManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PreferenceToggleRow(
                title: "Enable global “Trim Clipboard” hotkey",
                subtitle: "Instantly trims the clipboard without opening the menu.",
                binding: self.$settings.trimHotkeyEnabled)

            VStack(alignment: .leading, spacing: 6) {
                KeyboardShortcuts.Recorder("", name: .trimClipboard)
                    .labelsHidden()
                Text("Manual trims ignore the Aggressiveness setting and always use High.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

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
