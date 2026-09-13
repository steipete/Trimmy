import Testing
@testable import TrimmyCLI

struct CLIArgumentsTests {
    @Test
    func `short force option after trim is not a filename`() throws {
        let arguments = try CLIArguments(["--trim", "-f"])
        #expect(arguments.force)
        #expect(arguments.inputPath == nil)
    }

    @Test
    func `stdin marker and file paths are preserved`() throws {
        #expect(try CLIArguments(["--trim", "-"]).inputPath == "-")
        #expect(try CLIArguments(["-"]).inputPath == "-")
        #expect(try CLIArguments(["--trim", "some file.txt"]).inputPath == "some file.txt")
        #expect(try CLIArguments(["--trim", "-notes.txt"]).inputPath == "-notes.txt")
        #expect(try CLIArguments(["--trim", "./-f"]).inputPath == "./-f")
    }

    @Test
    func `options retain their settings and last value wins`() throws {
        let arguments = try CLIArguments([
            "--trim", "--force", "--json", "--aggressiveness", "HIGH",
            "--preserve-blank-lines", "--no-preserve-blank-lines", "--keep-box-drawing",
        ])
        #expect(arguments.inputPath == nil)
        #expect(arguments.force)
        #expect(arguments.json)
        #expect(arguments.settings.aggressiveness == .high)
        #expect(!arguments.settings.preserveBlankLines)
        #expect(!arguments.settings.removeBoxDrawing)
    }

    @Test(arguments: [["--unknown"], ["--aggressiveness"], ["--aggressiveness", "eager"]])
    func `invalid arguments are rejected`(arguments: [String]) {
        #expect(throws: CLIArgumentError.self) { try CLIArguments(arguments) }
    }
}
