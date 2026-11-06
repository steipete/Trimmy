import Testing
import TrimmyCore

struct PromptBoundaryTests {
    private let cleaner = TextCleaner()

    @Test(arguments: ["$HOME/bin/tool", "$PWD/script --help", "$git status", "#include <stdio.h>"])
    func `preserves tokens starting with a prompt character`(text: String) {
        #expect(self.cleaner.stripPromptPrefixes(text) == nil)
        let config = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        #expect(self.cleaner.transform(text, config: config).trimmed == text)
    }

    @Test(arguments: ["# GitHub Actions", "# Shell Overview", "# NodeJS Guide"])
    func `preserves headings whose words start with command names`(text: String) {
        #expect(self.cleaner.stripPromptPrefixes(text) == nil)
    }

    @Test(arguments: [
        ("$ go test ./... -v", "go test ./... -v"),
        ("$ cat the", "cat the"),
        ("$ make build release install", "make build release install"),
        ("$ lsblk", "lsblk"),
        ("$ shuf words", "shuf words"),
    ])
    func `strips a prompt from a real command with several arguments`(text: String, expected: String) {
        #expect(self.cleaner.stripPromptPrefixes(text) == expected)
    }

    @Test(arguments: ["$ show me the docs", "$ going home now"])
    func `does not strip a dollar prompt from an ordinary word`(text: String) {
        #expect(self.cleaner.stripPromptPrefixes(text) == nil)
    }

    @Test(arguments: [
        ("$ echo hello", "echo hello"),
        ("$ java -version", "java -version"),
        ("$ node server.js", "node server.js"),
        ("$ brew upgrade", "brew upgrade"),
        ("$ bundle exec fastlane", "bundle exec fastlane"),
        ("$ env", "env"),
        ("$ export PATH", "export PATH"),
        ("$ fish", "fish"),
    ])
    func `still strips a prompt from the exact command name`(text: String, expected: String) {
        #expect(self.cleaner.stripPromptPrefixes(text) == expected)
    }

    @Test(arguments: [
        "$ javascript tutorial",
        "$ echoing hello",
        "$ NodeJS Guide",
        "$ environment variables",
        "$ exported names",
        "$ fishy story",
        "$ brewery tour",
        "$ bundles of joy",
    ])
    func `does not strip a dollar prompt from a longer word that starts with a command`(text: String) {
        #expect(self.cleaner.stripPromptPrefixes(text) == nil)
    }

    @Test
    func `normal aggressiveness keeps two prose lines that share a command stem`() {
        let text = "javascript errors\nkeep happening"
        let normal = TrimConfig(aggressiveness: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        let low = TrimConfig(aggressiveness: .low, preserveBlankLines: false, removeBoxDrawing: true)
        #expect(self.cleaner.transform(text, config: normal).trimmed == text)
        #expect(self.cleaner.transform(text, config: low).trimmed == text)
    }

    @Test(arguments: [
        ("$ git status", "git status"),
        ("$ gitk", "gitk"),
        ("$ GIT status", "GIT status"),
        ("# Make clean", "Make clean"),
        ("# brew upgrade", "brew upgrade"),
        ("$\tpython3 --version", "python3 --version"),
        ("  $ ./script", "  ./script"),
    ])
    func `strips separated shell prompts`(text: String, expected: String) {
        #expect(self.cleaner.stripPromptPrefixes(text) == expected)
    }
}
