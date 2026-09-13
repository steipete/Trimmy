import Testing
import TrimmyCore

struct TextLiteralTests {
    private let cleaner = TextCleaner()

    @Test
    func `blank line preservation keeps literal placeholder text`() {
        let text = "echo __BLANK_SEP__ \\\n --verbose\n\nnext command"
        let result = self.cleaner.transformIfCommand(
            text,
            config: TrimConfig(aggressiveness: .high, preserveBlankLines: true, removeBoxDrawing: false))
        #expect(result == "echo __BLANK_SEP__ --verbose\n\nnext command")
    }

    @Test(arguments: ["\r\n", "\r"])
    func `command continuations support non Unix line endings`(newline: String) {
        let text = "echo first \\" + newline + " --verbose"
        let result = self.cleaner.transformIfCommand(
            text,
            config: TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: false))
        #expect(result == "echo first --verbose")
    }

    @Test
    func `path quoting preserves shell metacharacters literally`() {
        let path = #"/tmp/$TRIMMY_FIXTURE `printf changed` \ "file".txt"#
        let quoted = self.cleaner.quotePathWithSpaces(path)
        #expect(quoted == #""/tmp/\$TRIMMY_FIXTURE \`printf changed\` \\ \"file\".txt""#)
    }

    @Test
    func `carriage return separated paths stay multiline`() {
        #expect(self.cleaner.quotePathWithSpaces("/tmp/My Files\r/second/path") == nil)
    }
}
