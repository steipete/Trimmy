import Testing
@testable import Trimmy

@MainActor
struct ParagraphDedentIntegrationTests {
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
