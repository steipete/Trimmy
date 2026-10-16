import Foundation
import Testing
import TrimmyCore
@testable import TrimmyCLI

struct TrimmyCLITests {
    @Test
    func `explicit stdin marker reads piped input`() throws {
        let input = try TrimmyCLI.readInput(path: "-", isTTY: false) { Data("echo hello".utf8) }
        #expect(input == "echo hello")
    }

    @Test
    func `explicit stdin marker reads interactive input`() throws {
        var read = false
        let input = try TrimmyCLI.readInput(path: "-", isTTY: true) {
            read = true
            return Data("interactive input".utf8)
        }
        #expect(read)
        #expect(input == "interactive input")
    }

    @Test
    func `trims multiline command`() {
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
    func `text mode adds one newline without treating it as a trim`() throws {
        let unchanged = try Self.runTextCLI("hello\n")
        #expect(unchanged.stdout == "hello\n")
        #expect(unchanged.status == 2)

        let added = try Self.runTextCLI("hello")
        #expect(added.stdout == "hello\n")
        #expect(added.status == 2)

        let doubled = try Self.runTextCLI("hello\n\n")
        #expect(doubled.stdout == "hello\n\n")
        #expect(doubled.status == 2)

        let trimmed = try Self.runTextCLI("echo hi\nls -la")
        #expect(trimmed.stdout == "echo hi ls -la\n")
        #expect(trimmed.status == 0)
    }

    private static func runTextCLI(_ input: String) throws -> (stdout: String, status: Int32) {
        let process = Process()
        process.executableURL = try Self.trimmyCLIURL()
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = FileHandle.nullDevice
        try process.run()
        inputPipe.fileHandleForWriting.write(Data(input.utf8))
        try inputPipe.fileHandleForWriting.close()
        let data = outputPipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        guard let stdout = String(bytes: data, encoding: .utf8) else {
            throw CocoaError(.fileReadCorruptFile)
        }
        return (stdout, process.terminationStatus)
    }

    private static func trimmyCLIURL() throws -> URL {
        let root = URL(fileURLWithPath: #filePath)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let build = root.appendingPathComponent(".build")
        guard let enumerator = FileManager.default.enumerator(
            at: build,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles])
        else {
            throw CocoaError(.fileNoSuchFile)
        }
        var matches: [URL] = []
        for case let url as URL in enumerator {
            guard url.lastPathComponent == "TrimmyCLI", !url.path.contains(".dSYM") else { continue }
            if FileManager.default.isExecutableFile(atPath: url.path) {
                matches.append(url)
            }
        }
        guard let url = matches.max(by: { left, right in
            Self.modificationDate(left) < Self.modificationDate(right)
        }) else {
            throw CocoaError(.fileNoSuchFile)
        }
        return url
    }

    private static func modificationDate(_ url: URL) -> Date {
        (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
    }

    @Test
    func `no change single line`() {
        let input = "single line"
        let result = cliTrim(input, settings: CLISettings(), force: false)
        #expect(result.transformed == false)
        #expect(result.trimmed == input)
    }

    @Test
    func `removes box drawing`() {
        let input = "│ ls -la"
        let result = cliTrim(input, settings: CLISettings(removeBoxDrawing: true), force: false)
        #expect(result.transformed)
        #expect(!result.trimmed.contains("│"))
    }

    @Test
    func `preserves blank lines when requested`() {
        let input = "a\n\nb"
        let result = cliTrim(input, settings: CLISettings(preserveBlankLines: true), force: false)
        #expect(result.trimmed.contains("\n\n"))
    }

    @Test
    func `dedents prose copied with shared indentation`() {
        let input = """
        Hello,
         This paragraph line has accidental indentation.
         This one does too.
        """
        let expected = """
        Hello,
        This paragraph line has accidental indentation.
        This one does too.
        """

        let result = cliTrim(input, settings: CLISettings(), force: false)
        #expect(result.transformed)
        #expect(result.trimmed == expected)
    }

    @Test
    func `ignores structured json`() {
        let input = """
        {
          "Version": "2012-10-17",
          "Statement": [
            {
              "Effect": "Allow",
              "Action": [
                "s3:GetObject",
                "s3:PutObject",
                "s3:ListBucket"
              ],
              "Resource": [
                "arn:aws:s3:::bucket-in-account-a",
                "arn:aws:s3:::bucket-in-account-a/*"
              ]
            }
          ]
        }
        """
        let result = cliTrim(input, settings: CLISettings(), force: false)
        #expect(result.transformed == false)
        #expect(result.trimmed == input)
    }

    @Test(arguments: [
        "description: |\n  This paragraph belongs to a YAML scalar.\n  Its indentation is required.",
        "art: |\n  │ hello\n  │ world",
        "script: &anchor |\n  $ echo one\n  $ echo two",
        "description: !!str |\n  This paragraph belongs to a YAML scalar.\n  Its indentation is required.",
    ])
    func `preserves YAML literal blocks`(input: String) {
        for aggressiveness in [Aggressiveness.low, .normal] {
            let result = cliTrim(input, settings: CLISettings(aggressiveness: aggressiveness), force: false)
            #expect(!result.transformed)
            #expect(result.trimmed == input)
        }
    }

    @Test
    func `pyenv init stays multiline when safer`() {
        let input = """
        export PYENV_ROOT="$HOME/.pyenv"
        [[ -d $PYENV_ROOT/bin ]] && export PATH="$PYENV_ROOT/bin:$PATH"
        eval "$(pyenv init - zsh)"
        """
        let normal = CLISettings(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let resultNormal = cliTrim(input, settings: normal, force: false)
        #expect(resultNormal.transformed == false)
        #expect(resultNormal.trimmed == input)

        let high = CLISettings(aggressiveness: .high, preserveBlankLines: false, removeBoxDrawing: true)
        let resultHigh = cliTrim(input, settings: high, force: false)
        #expect(resultHigh.transformed == true)
        #expect(!resultHigh.trimmed.contains("\n"))
    }

    @Test
    func `read input does not block when tty`() throws {
        let input = try TrimmyCLI.readInput(path: nil, isTTY: true)
        #expect(input == nil)

        let piped = Data("echo hi".utf8)
        let pipedResult = try TrimmyCLI.readInput(path: nil, isTTY: false) { piped }
        #expect(pipedResult == "echo hi")
    }

    @Test
    func `version string available`() {
        #expect(!TrimmyCLI.bundledVersion.isEmpty)
    }

    @Test
    func `help includes version and synopsis`() {
        let help = TrimmyCLI.helpText(version: "0.6.0-test")
        #expect(help.contains("Version: 0.6.0-test"))
        #expect(help.contains("trimmy --trim"))
    }
}
