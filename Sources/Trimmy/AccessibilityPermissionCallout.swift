import AppKit
import SwiftUI

@MainActor
struct AccessibilityPermissionCallout: View {
    @ObservedObject var permissions: AccessibilityPermissionManager
    var compactButtons: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Label {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Bedienungshilfen für Einfügen benötigt")
                        .font(.callout.weight(.semibold))
                    Text(
                        "Trimmy in Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen "
                            + "aktivieren, damit ⌘V an die aktive App gesendet werden kann.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            } icon: {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.yellow)
            }

            HStack(spacing: 10) {
                Button("Bedienungshilfen erlauben") {
                    self.permissions.requestPermissionPrompt()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(self.compactButtons ? .small : .regular)

                Button("Einstellungen öffnen") {
                    self.permissions.openSystemSettings()
                }
                .buttonStyle(.bordered)
                .controlSize(self.compactButtons ? .small : .regular)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(nsColor: .controlBackgroundColor))
                .overlay(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(Color(nsColor: .separatorColor), lineWidth: 1)))
    }
}
