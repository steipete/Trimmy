import Foundation
import Testing
@testable import Trimmy

@MainActor
struct CLIInstallerTests {
    @Test
    func `shell command preserves literal paths`() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let helper = directory.appendingPathComponent("$TRIMMY_FIXTURE `printf changed` 'quoted' \\\"app\\\"/helper")
        let target = directory.appendingPathComponent("bin 'quoted'/trimmy")
        let command = CLIInstaller.installCommand(helperURL: helper, targets: [target])
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/sh")
        process.arguments = ["-c", command]
        try process.run()
        process.waitUntilExit()
        #expect(process.terminationStatus == 0)
        #expect(try FileManager.default.destinationOfSymbolicLink(atPath: target.path) == helper.path)
    }

    @Test
    func `AppleScript encoding preserves shell command characters`() async throws {
        let command = "/bin/echo 'a \\\"quote\\\" and $value and \\backslash and\nnewline'"
        let result = try await CLIInstaller.runAppleScript("return \(CLIInstaller.appleScriptString(command))")
        #expect(result.exitCode == 0)
        #expect(result.output == command)
    }

    @Test
    func `waiting for the installer leaves the main actor responsive`() async throws {
        var heartbeatRan = false
        let heartbeat = Task { heartbeatRan = true }
        let result = try await CLIInstaller.runAppleScript("delay 0.2\nreturn \"finished\"")
        #expect(heartbeatRan)
        #expect(result.exitCode == 0)
        #expect(result.output == "finished")
        await heartbeat.value
    }

    @Test
    func `missing helper reports the reinstall action`() async {
        let helper = URL(fileURLWithPath: "/nonexistent-trimmy-fixture/helper")
        #expect(await CLIInstaller.install(helperURL: helper) == "Helper missing; reinstall Trimmy.")
    }
}
