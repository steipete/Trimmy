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
                title: "Auto-Trim aktiviert",
                subtitle: "Zwischenablage automatisch kürzen, wenn der Inhalt wie ein Befehl aussieht.",
                binding: self.$settings.autoTrimEnabled)

            PreferenceToggleRow(
                title: "Kontextabhängiges Trimmen",
                subtitle: "Terminal-spezifische Aggressivität verwenden, wenn ein Terminal erkannt wird "
                    + "(Cmd-C + App-Snapshot).",
                binding: self.$settings.contextAwareTrimmingEnabled)

            PreferenceToggleRow(
                title: "Leerzeilen beibehalten",
                subtitle: "Beabsichtigte Leerzeilen beibehalten statt sie zusammenzufassen.",
                binding: self.$settings.preserveBlankLines)

            PreferenceToggleRow(
                title: "Box-Drawing-Zeichen entfernen (│┃)",
                subtitle: "Prompt-Box-Rahmen (beliebige Anzahl, führend/nachfolgend) vor dem Trimmen entfernen.",
                binding: self.$settings.removeBoxDrawing)

            PreferenceToggleRow(
                title: "Markdown-Neuformatierung anzeigen",
                subtitle: "Einfüge-Aktion im Menü, die Markdown-Aufzählungen und Überschriften neu formatiert.",
                binding: self.$settings.showMarkdownReformatOption)

            Divider()
                .padding(.vertical, 4)

            PreferenceToggleRow(
                title: "Bei Anmeldung starten",
                subtitle: "Öffnet die App automatisch beim Mac-Start.",
                binding: self.$settings.launchAtLogin)

            HStack {
                Spacer()
                Button("Trimmy beenden") {
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
