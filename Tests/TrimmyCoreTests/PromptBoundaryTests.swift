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
