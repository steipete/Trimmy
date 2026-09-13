import KeyboardShortcuts
import SwiftUI

@MainActor
struct HotkeySettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPaneLayout {
            SettingsSection(
                "Global shortcuts",
                subtitle: "These shortcuts work from any app. Click a recorder to assign a different key combination.")
            {
                VStack(alignment: .leading, spacing: 16) {
                    ShortcutSettingsRow(
                        title: "Paste Trimmed",
                        subtitle: "Trim with High sensitivity, paste, then restore the clipboard.",
                        isEnabled: self.$settings.pasteTrimmedHotkeyEnabled,
                        shortcut: .pasteTrimmed)

                    Divider()

                    ShortcutSettingsRow(
                        title: "Paste Original",
                        subtitle: "Paste the untouched copy even after auto-trim changed the clipboard.",
                        isEnabled: self.$settings.pasteOriginalHotkeyEnabled,
                        shortcut: .pasteOriginal)

                    Divider()

                    ShortcutSettingsRow(
                        title: "Toggle Auto-Trim",
                        subtitle: "Turn automatic trimming on or off without opening Trimmy.",
                        isEnabled: self.$settings.autoTrimHotkeyEnabled,
                        shortcut: .toggleAutoTrim)
                }
            }
        }
    }
}

@MainActor
private struct ShortcutSettingsRow: View {
    let title: String
    let subtitle: String
    @Binding var isEnabled: Bool
    let shortcut: KeyboardShortcuts.Name

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .center, spacing: 12) {
                Toggle(self.title, isOn: self.$isEnabled)
                    .toggleStyle(.checkbox)
                Spacer()
                KeyboardShortcuts.Recorder("", name: self.shortcut)
                    .labelsHidden()
                    .opacity(self.isEnabled ? 1.0 : 0.4)
                    .disabled(!self.isEnabled)
            }

            Text(self.subtitle)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}
