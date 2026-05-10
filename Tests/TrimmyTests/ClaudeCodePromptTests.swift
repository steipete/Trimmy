import Foundation
import Testing
import TrimmyCore
@testable import Trimmy

@MainActor
struct ClaudeCodePromptTests {
    private let cleaner = TextCleaner()

    // MARK: - Scenario A: Full decoration (❯ + rule + duplicate content)

    @Test
    func `strips full decoration`() {
        let text = """
        ❯ /skill:cmd "some args"
        ──────────────────────
        /skill:cmd "some args"
          --flag value
        """
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == "/skill:cmd \"some args\" --flag value")
    }

    @Test
    func `flattens full decoration with wrapped args`() {
        let text = """
        ❯ /my-skill:run-task "Analyze the dataset
          for patterns and report
          findings" --max-iterations 10
        ────────────────────────────────────────
        /my-skill:run-task "Analyze the dataset
          for patterns and report
          findings" --max-iterations 10
        """
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result ==
            "/my-skill:run-task \"Analyze the dataset for patterns and report findings\" --max-iterations 10")
    }

    // MARK: - Scenario B: Raw slash command (multi-line, no decoration)

    @Test
    func `flattens raw slash command`() {
        let text = """
        /skill:cmd "args
          wrapped" --flag
        """
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == "/skill:cmd \"args wrapped\" --flag")
    }

    @Test
    func `flattens raw slash command with arguments on continuation line`() {
        let text = """
        /commit
          --amend --no-edit
        """
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == "/commit --amend --no-edit")
    }

    // MARK: - Scenario A/C hybrid: short prompt with decoration

    @Test
    func `strips short prompt with decoration`() {
        let text = """
        ❯ /commit
        ──────────
        /commit
        """
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == "/commit")
    }

    // MARK: - Scenario C: ❯ prefix only (single line)

    @Test
    func `strips partial prompt prefix`() {
        let text = "❯ /commit"
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == "/commit")
    }

    // MARK: - Scenario E: Outer-quoted slash command

    @Test
    func `strips outer quotes and unescapes`() {
        let text = #""/my-skill:run-task \"Analyze the data for anomalies\" --max-iterations=50""#
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == #"/my-skill:run-task "Analyze the data for anomalies" --max-iterations=50"#)
    }

    @Test
    func `strips outer quotes long prompt`() {
        let text = #""/my-skill:run-task \"Run a full analysis on the dataset. Check for patterns and outliers. "# +
            #"Verify all results against baseline. Continue iterating until confidence is high enough to report.\" "# +
            #"--max-iterations=100""#
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result != nil)
        #expect(result?.hasPrefix("/my-skill:run-task \"Run a full") == true)
        #expect(result?.hasSuffix("--max-iterations=100") == true)
        #expect(result?.contains("\\\"") == false)
    }

    // MARK: - Negative cases

    @Test
    func `does not flatten plain terminal wrapped text`() {
        let text = """
        This is a long paragraph that got
          wrapped by the terminal to the
          next line automatically
        """
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == nil)
    }

    @Test
    func `does not flatten code`() {
        let text = """
        func hello() {
            print("world")
        }
        """
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == nil)
    }

    @Test
    func `does not flatten lists`() {
        let text = """
        - item one
        - item two
        - item three
        """
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == nil)
    }

    @Test
    func `does not flatten multi paragraph`() {
        let text = """
        First paragraph that is
          long enough.

        Second paragraph here
          also wrapped.
        """
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == nil)
    }

    @Test
    func `does not strip plain single line`() {
        let text = "just a single line of text"
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: true)
        #expect(result == nil)
    }

    // MARK: - Setting respect

    @Test
    func `respects disabled setting`() {
        let text = """
        ❯ /commit
        ──────────
        /commit
        """
        let result = self.cleaner.stripClaudeCodeDecoration(text, enabled: false)
        #expect(result == nil)
    }

    // MARK: - Full pipeline integration

    @Test
    func `full pipeline integration`() {
        let text = """
        ❯ /commit
        ──────────
        /commit
        """
        let config = TrimConfig(
            aggressiveness: .normal,
            preserveBlankLines: false,
            removeBoxDrawing: true,
            flattenClaudeCodePrompts: true)
        let result = self.cleaner.transform(text, config: config)
        #expect(result.wasTransformed)
        #expect(result.trimmed == "/commit")
    }

    @Test
    func `pipeline disabled setting`() {
        let text = """
        ❯ /commit
        ──────────
        /commit
        """
        let config = TrimConfig(
            aggressiveness: .normal,
            preserveBlankLines: false,
            removeBoxDrawing: true,
            flattenClaudeCodePrompts: false)
        let result = self.cleaner.transform(text, config: config)
        #expect(result.trimmed == "❯ /commit\n──────────\n/commit")
    }
}
