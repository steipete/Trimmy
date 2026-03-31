import SwiftUI

@MainActor
struct AdvancedSettingsPane: View {
    @ObservedObject var settings: AppSettings
    @State private var isInstallingCLI = false
    @State private var cliStatus: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PreferenceToggleRow(
                title: "Zusätzliche Zwischenablage-Fallbacks",
                subtitle: "RTF und öffentliche Texttypen versuchen, wenn Klartext fehlt.",
                binding: self.$settings.usePasteboardFallbacks)

            self.cliInstallerSection

            #if DEBUG
            PreferenceToggleRow(
                title: "Debug-Werkzeuge aktivieren",
                subtitle: "Debug-Tab für Vorschau und Entwickler-Optionen anzeigen.",
                binding: self.$settings.debugPaneEnabled)
            #endif
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }

    private var cliInstallerSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Button {
                    Task { await self.installCLI() }
                } label: {
                    if self.isInstallingCLI {
                        ProgressView().controlSize(.small)
                    } else {
                        Text("CLI installieren")
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

            Text("`trimmy` nach /usr/local/bin und /opt/homebrew/bin installieren.")
                .font(.callout)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    // MARK: - CLI installer

    private func installCLI() async {
        guard !self.isInstallingCLI else { return }
        self.isInstallingCLI = true
        defer { self.isInstallingCLI = false }

        let helperURL = Bundle.main.bundleURL
            .appendingPathComponent("Contents")
            .appendingPathComponent("Helpers")
            .appendingPathComponent("TrimmyCLI")

        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            await MainActor.run { self.cliStatus = "Helper fehlt; Trimmy neu installieren." }
            return
        }

        let installScript = """
        #!/usr/bin/env bash
        set -euo pipefail
        HELPER=\"\(helperURL.path)\"
        TARGETS=(\"/usr/local/bin/trimmy\" \"/opt/homebrew/bin/trimmy\")

        for t in \"${TARGETS[@]}\"; do
          mkdir -p \"$(dirname \"$t\")\"
          ln -sf \"$HELPER\" \"$t\"
          echo \"Linked $t -> $HELPER\"
        done
        """

        do {
            let scriptURL = FileManager.default.temporaryDirectory
                .appendingPathComponent("install_trimmy_cli.sh")
            defer { try? FileManager.default.removeItem(at: scriptURL) }
            try installScript.write(to: scriptURL, atomically: true, encoding: .utf8)
            try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: scriptURL.path)

            let escapedPath = scriptURL.path.replacingOccurrences(of: "\"", with: "\\\"")
            let appleScript = "do shell script \"bash \\\"\(escapedPath)\\\"\" with administrator privileges"

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", appleScript]
            let stderrPipe = Pipe()
            process.standardError = stderrPipe

            try process.run()
            process.waitUntilExit()
            let status: String
            if process.terminationStatus == 0 {
                status = "Installiert. Teste: trimmy --help"
            } else {
                let data = stderrPipe.fileHandleForReading.readDataToEndOfFile()
                let msg = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                status = "Fehlgeschlagen: \(msg ?? "Fehler")"
            }
            await MainActor.run { self.cliStatus = status }
        } catch {
            await MainActor.run { self.cliStatus = "Fehlgeschlagen: \(error.localizedDescription)" }
        }
    }
}
