import Testing
@testable import Trimmy

struct MarkdownBlockBoundaryTests {
    @Test(arguments: ["```", "~~~"])
    func `trailing content does not close a code fence`(fence: String) {
        let text = "\(fence)text\nbefore\n\(fence)not a closer\nstill inside\nkeep line break\n\(fence)"
        #expect(MarkdownReformatter.reformat(text) == text)
    }

    @Test(arguments: ["1.foo\n2.bar", "1)foo\n2)bar", "①. foo\n②. bar", "1234567890. foo\n1234567891. bar"])
    func `non Markdown numeric prefixes remain prose`(text: String) {
        #expect(!MarkdownReformatter.isLikelyMarkdown(text))
        #expect(MarkdownReformatter.reformat(text) == text.replacingOccurrences(of: "\n", with: " "))
    }

    @Test
    func `numbered items accept tabs after the marker`() {
        let text = "1.\tfirst\n2.\tsecond"
        #expect(MarkdownReformatter.isLikelyMarkdown(text))
        #expect(MarkdownReformatter.reformat(text) == "1. first\n2. second")
    }

    @Test
    func `longer fence followed by whitespace closes the block`() {
        let text = "```text\nkeep\nlines\n```` \t\nJoin this\nparagraph."
        #expect(MarkdownReformatter.reformat(text) == "```text\nkeep\nlines\n```` \t\nJoin this paragraph.")
    }
}
