import Foundation

enum CLIInstaller {
    struct CommandResult: Sendable {
        let exitCode: Int32
        let output: String
    }

    static func install(helperURL: URL) async -> String {
        guard FileManager.default.isExecutableFile(atPath: helperURL.path) else {
            return "Helper missing; reinstall Trimmy."
        }
        let targets = ["/usr/local/bin/trimmy", "/opt/homebrew/bin/trimmy"].map { URL(fileURLWithPath: $0) }
        let command = self.installCommand(helperURL: helperURL, targets: targets)
        let source = "do shell script \(self.appleScriptString(command)) with administrator privileges"
        do {
            let result = try await self.runAppleScript(source)
            return result.exitCode == 0 ? "Installed. Try: trimmy --help" : "Failed: \(result.output)"
        } catch {
            return "Failed: \(error.localizedDescription)"
        }
    }

    static func installCommand(helperURL: URL, targets: [URL]) -> String {
        targets.map { target in
            "/bin/mkdir -p \(self.shellQuote(target.deletingLastPathComponent().path))"
                + " && /bin/ln -sfn \(self.shellQuote(helperURL.path)) \(self.shellQuote(target.path))"
        }.joined(separator: " && ")
    }

    static func appleScriptString(_ value: String) -> String {
        let escaped = value.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
        return "\"\(escaped)\""
    }

    private static func shellQuote(_ value: String) -> String {
        "'" + value.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }

    static func runAppleScript(_ source: String) async throws -> CommandResult {
        try await Task.detached {
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
            process.arguments = ["-e", source]
            let output = Pipe()
            process.standardOutput = output
            process.standardError = output
            try process.run()
            let data = output.fileHandleForReading.readDataToEndOfFile()
            process.waitUntilExit()
            return CommandResult(
                exitCode: process.terminationStatus,
                output: String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
                    ?? "The installer returned unreadable output.")
        }.value
    }
}
