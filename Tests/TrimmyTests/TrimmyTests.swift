import Foundation
import Testing
@testable import Trimmy

@MainActor
@Suite
struct TrimmyTests {
    @Test
    func detectsMultiLineCommand() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        settings.preserveBlankLines = false
        let detector = CommandDetector(settings: settings)
        let text = "echo hi\nls -la\n"
        #expect(detector.transformIfCommand(text) == "echo hi ls -la")
    }

    @Test
    func skipsSingleLine() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        #expect(detector.transformIfCommand("ls -la") == nil)
    }

    @Test
    func skipsLongCopies() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let blob = Array(repeating: "echo hi", count: 11).joined(separator: "\n")
        #expect(detector.transformIfCommand(blob) == nil)
    }

    @Test
    func preservesBlankLinesWhenEnabled() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        settings.preserveBlankLines = true
        let detector = CommandDetector(settings: settings)
        let text = "echo hi\n\necho bye\n"
        #expect(detector.transformIfCommand(text) == "echo hi\n\necho bye")
    }

    @Test
    func flattensBackslashContinuations() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        python script.py \\
          --flag yes \\
          --count 2
        """
        #expect(detector.transformIfCommand(text) == "python script.py --flag yes --count 2")
    }

    @Test
    func repairsAllCapsTokenBreaks() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = "N\nODE_PATH=/usr/bin\nls"
        #expect(detector.transformIfCommand(text) == "NODE_PATH=/usr/bin ls")
    }

    @Test
    func collapsesBlankLinesWhenNotPreserved() {
        let settings = AppSettings()
        settings.preserveBlankLines = false
        settings.aggressiveness = .high // allow flattening with minimal cues
        let detector = CommandDetector(settings: settings)
        let text = "echo a\n\necho b"
        #expect(detector.transformIfCommand(text) == "echo a echo b")
    }

    @Test
    func ignoresHarmlessMultilineText() {
        let settings = AppSettings()
        settings.aggressiveness = .low // stricter threshold to avoid flattening prose
        let detector = CommandDetector(settings: settings)
        let text = "Shopping list:\napples\noranges"
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func lowAggressivenessNeedsClearSignals() {
        let settings = AppSettings()
        settings.aggressiveness = .low
        let detector = CommandDetector(settings: settings)
        let text = """
        echo hello
        world
        """
        #expect(detector.transformIfCommand(text) == nil)
    }

    @Test
    func highAggressivenessFlattensLooseCommands() {
        let settings = AppSettings()
        settings.aggressiveness = .high
        let detector = CommandDetector(settings: settings)
        let text = """
        npm
        install
        """
        #expect(detector.transformIfCommand(text) == "npm install")
    }

    @Test
    func normalAggressivenessKeepsNonCommands() {
        let settings = AppSettings()
        settings.aggressiveness = .normal
        let detector = CommandDetector(settings: settings)
        let text = """
        Meeting notes:
        bullet
        items
        """
        #expect(detector.transformIfCommand(text) == "Meeting notes: bullet items")
    }

    @Test
    func preserveBlankLinesRoundTrip() {
        let settings = AppSettings()
        settings.aggressiveness = .high
        settings.preserveBlankLines = true
        let detector = CommandDetector(settings: settings)
        let text = """
        echo a \\
        --flag yes

        echo b
        """
        #expect(detector.transformIfCommand(text) == "echo a --flag yes\n\necho b")
    }

    @Test
    func backslashWithoutCommandShouldFlattenOnlyWhenHigh() {
        let settings = AppSettings()
        settings.aggressiveness = .low
        let detectorLow = CommandDetector(settings: settings)
        let text = """
        Not really a command \\
        just text
        """
        #expect(detectorLow.transformIfCommand(text) == "Not really a command just text")

        let settingsHigh = AppSettings()
        settingsHigh.aggressiveness = .high
        let detectorHigh = CommandDetector(settings: settingsHigh)
        #expect(detectorHigh.transformIfCommand(text) == "Not really a command just text")
    }
}
