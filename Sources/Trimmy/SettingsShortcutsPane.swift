import KeyboardShortcuts
import SwiftUI

@MainActor
struct HotkeySettingsPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var hotkeyManager: HotkeyManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PreferenceToggleRow(
                title: “Globalen „Getrimmt einfügen”-Hotkey aktivieren”,
                subtitle: “Spontan trimmen und einfügen, ohne die Zwischenablage dauerhaft zu ändern.”,
                binding: self.$settings.pasteTrimmedHotkeyEnabled)

            VStack(alignment: .leading, spacing: 6) {
                KeyboardShortcuts.Recorder(“”, name: .pasteTrimmed)
                    .labelsHidden()
                    .opacity(self.settings.pasteTrimmedHotkeyEnabled ? 1.0 : 0.4)
                    .disabled(!self.settings.pasteTrimmedHotkeyEnabled)
                Text(“Getrimmt einfügen nutzt immer Aggressivität Hoch und stellt danach die Zwischenablage wieder her.”)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }

            PreferenceToggleRow(
                title: “Globalen „Original einfügen”-Hotkey aktivieren”,
                subtitle: “Die unveränderte Kopie einfügen, auch wenn Trimmy bereits getrimmt hat.”,
                binding: self.$settings.pasteOriginalHotkeyEnabled)

            KeyboardShortcuts.Recorder(“”, name: .pasteOriginal)
                .labelsHidden()
                .opacity(self.settings.pasteOriginalHotkeyEnabled ? 1.0 : 0.4)
                .disabled(!self.settings.pasteOriginalHotkeyEnabled)

            PreferenceToggleRow(
                title: “Globalen Auto-Trim-Umschalt-Hotkey aktivieren”,
                subtitle: “Auto-Trim schnell ein- oder ausschalten, ohne das Menü zu öffnen.”,
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
