import Foundation
import Testing
@testable import TrimmyCLI

struct TrimmyCLITests {
    @Test
    func trimsMultilineCommand() {
        let input = """
        echo hi \\
        ls -la
        """
        let result = cliTrim(
            input,
            settings: CLISettings(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true),
            force: false)
        #expect(result.transformed)
        #expect(!result.trimmed.contains("\n"))
    }

    @Test
    func noChangeSingleLine() {
        let input = "single line"
        let result = cliTrim(input, settings: CLISettings(), force: false)
        #expect(result.transformed == false)
        #expect(result.trimmed == input)
    }

    @Test
    func removesBoxDrawing() {
        let input = "│ ls -la"
        let result = cliTrim(input, settings: CLISettings(removeBoxDrawing: true), force: false)
        #expect(result.transformed)
        #expect(!result.trimmed.contains("│"))
    }

    @Test
    func preservesBlankLinesWhenRequested() {
        let input = "a\n\nb"
        let result = cliTrim(input, settings: CLISettings(preserveBlankLines: true), force: false)
        #expect(result.trimmed.contains("\n\n"))
    }

    @Test
    func readInputDoesNotBlockWhenTty() {
        let input = TrimmyCLI._testReadInput(path: nil, stdinData: nil, isTTY: true)
        #expect(input == nil)

        let piped = Data("echo hi".utf8)
        let pipedResult = TrimmyCLI._testReadInput(path: nil, stdinData: piped, isTTY: false)
        #expect(pipedResult == "echo hi")
    }

    @Test
    func versionStringAvailable() {
        #expect(!TrimmyCLI._testVersion.isEmpty)
    }

    @Test
    func helpIncludesVersionAndSynopsis() {
        let help = TrimmyCLI.helpText(version: "0.6.0-test")
        #expect(help.contains("Version: 0.6.0-test"))
        #expect(help.contains("trimmy --trim"))
    }
}
