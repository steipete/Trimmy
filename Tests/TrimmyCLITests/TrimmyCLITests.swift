import Foundation
import Testing
import TrimmyCore
@testable import TrimmyCLI

struct TrimmyCLITests {
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
    func `read input does not block when tty`() {
        let input = TrimmyCLI._testReadInput(path: nil, stdinData: nil, isTTY: true)
        #expect(input == nil)

        let piped = Data("echo hi".utf8)
        let pipedResult = TrimmyCLI._testReadInput(path: nil, stdinData: piped, isTTY: false)
        #expect(pipedResult == "echo hi")
    }

    @Test
    func `version string available`() {
        #expect(!TrimmyCLI._testVersion.isEmpty)
    }

    @Test
    func `help includes version and synopsis`() {
        let help = TrimmyCLI.helpText(version: "0.6.0-test")
        #expect(help.contains("Version: 0.6.0-test"))
        #expect(help.contains("trimmy --trim"))
    }
}
