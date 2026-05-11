import Testing
@testable import Trimmy
@testable import TrimmyCore

@MainActor
struct ParagraphDedentTests {
    private let cleaner = TextCleaner()

    @Test
    func `dedents copied prose with shared paragraph indentation`() {
        let input = """
        Hi Sarah,

         Thanks for getting back to me so quickly!

         I wanted to follow up on our earlier conversation about the project timeline.

         Let me know if you have any questions.
        """

        let expected = """
        Hi Sarah,

        Thanks for getting back to me so quickly!

        I wanted to follow up on our earlier conversation about the project timeline.

        Let me know if you have any questions.
        """

        #expect(self.cleaner.dedentParagraphIndent(input) == expected)
    }

    @Test
    func `dedents all indented prose lines by common indent only`() {
        let input = """
          First paragraph line.
            Nested detail stays relatively indented.
          Final paragraph line.
        """

        let expected = """
        First paragraph line.
          Nested detail stays relatively indented.
        Final paragraph line.
        """

        #expect(self.cleaner.dedentParagraphIndent(input) == expected)
    }

    @Test
    func `does not dedent bullet lists`() {
        let input = """
          - first item
          - second item
          - third item
        """

        #expect(self.cleaner.dedentParagraphIndent(input) == nil)
    }

    @Test
    func `does not dedent source code`() {
        let input = """
          struct Example {
              let value = 1
          }
        """

        #expect(self.cleaner.dedentParagraphIndent(input) == nil)
    }

    @Test
    func `does not dedent structured json`() {
        let input = """
          {
            "name": "Trimmy",
            "enabled": true
          }
        """

        #expect(self.cleaner.dedentParagraphIndent(input) == nil)
    }

    @Test
    func `does not run before command flattening`() {
        let config = TrimConfig(
            aggressiveness: .normal,
            preserveBlankLines: false,
            removeBoxDrawing: true)
        let input = """
        echo hello \\
          && echo world
        """

        let result = self.cleaner.transform(input, config: config)
        #expect(result.trimmed == "echo hello && echo world")
    }

    @Test
    func `clipboard detector exposes paragraph dedent`() {
        let settings = AppSettings()
        let detector = CommandDetector(settings: settings)
        let input = """
        Hello,
         This line has accidental indent.
         This one too.
        """

        let expected = """
        Hello,
        This line has accidental indent.
        This one too.
        """

        #expect(detector.dedentParagraphIndent(input) == expected)
    }
}
