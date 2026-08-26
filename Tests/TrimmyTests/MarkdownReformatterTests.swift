import Testing
@testable import Trimmy

struct MarkdownReformatterTests {
    @Test
    func `reflows wrapped bullets and keeps blank lines`() {
        let input = """
        - OpenAI Responses 400: "Item 'rs_...' of type 'reasoning' was provided
          without its required following item."
        - Trigger: history replay includes assistant turns with only
          thinking/reasoning (often from aborted runs). pi-ai replays
          thinkingSignature as a reasoning item even when the same turn has
          no message or function_call.

        Fix summary (pi-mono)

        - packages/ai/src/providers/openai-responses.ts: only replay
          reasoning if the assistant turn also has text or toolCall; prevents
          lone reasoning items.
        - Regression test added: packages/ai/test/openai-responses-reasoning-
          replay.test.ts.
        - Changelog entry under packages/ai/CHANGELOG.md.
        """

        let expected = [
            "- OpenAI Responses 400: \"Item 'rs_...' of type 'reasoning' was provided "
                + "without its required following item.\"",
            "- Trigger: history replay includes assistant turns with only thinking/reasoning "
                + "(often from aborted runs). "
                + "pi-ai replays thinkingSignature as a reasoning item even when the same turn has "
                + "no message or function_call.",
            "",
            "Fix summary (pi-mono)",
            "",
            "- packages/ai/src/providers/openai-responses.ts: only replay reasoning if the assistant "
                + "turn also has text or toolCall; prevents lone reasoning items.",
            "- Regression test added: packages/ai/test/openai-responses-reasoning-replay.test.ts.",
            "- Changelog entry under packages/ai/CHANGELOG.md.",
        ].joined(separator: "\n")

        let result = MarkdownReformatter.reformat(input)
        #expect(result == expected)
    }

    @Test
    func `keeps fenced code blocks`() {
        let input = """
        - First item with code:
        ```
        let a = 1
        let b = 2
        ```
        - Second item
        """

        let expected = """
        - First item with code:
        ```
        let a = 1
        let b = 2
        ```
        - Second item
        """

        let result = MarkdownReformatter.reformat(input)
        #expect(result == expected)
    }

    @Test
    func `reflows paragraphs and bullet glyph lists`() {
        let input = """
        The test process is still running, so I'll keep polling for updates
          until completion and then respond with the final status.

        • Hi Peter — the CI run 21126984283 is still in progress. The Android
          test succeeded, while Windows test, Bun test, Node test, macOS app,
          macOS checks, and iOS tests remain. If you'd like me to keep
          watching, just say "continue."
        """

        let expected = [
            "The test process is still running, so I'll keep polling for updates until completion "
                + "and then respond with the final status.",
            "",
            "• Hi Peter — the CI run 21126984283 is still in progress. The Android test succeeded, "
                + "while Windows test, Bun test, Node test, macOS app, macOS checks, and iOS tests remain. "
                + "If you'd like me to keep watching, just say \"continue.\"",
        ].joined(separator: "\n")

        let result = MarkdownReformatter.reformat(input)
        #expect(result == expected)
    }

    @Test
    func `detects markdown by headings and lists`() {
        let input = """
        ## Title
        - One
        - Two
        """

        #expect(MarkdownReformatter.isLikelyMarkdown(input))
    }

    @Test
    func `ignores plain wrapped text`() {
        let input = """
        This is a wrapped paragraph
        with no markdown markers.
        """

        #expect(!MarkdownReformatter.isLikelyMarkdown(input))
    }

    @Test
    func `detects long hard wrapped prose for reflow`() {
        let input = """
        The operative danger is the gradient between the source's coherence and the
        receiver's capacity. A prepared vessel metabolizes contact as gnosis while an
        unprepared vessel can undergo fragmentation or symbolic death.

        The face is the stable interface between the inner being and the social world.
        Divine contact transforms that interface when the inherited identity cannot
        carry the revelation.
        """

        #expect(!MarkdownReformatter.isLikelyMarkdown(input))
        #expect(MarkdownReformatter.isLikelyReflowable(input))
        let expected = [
            "The operative danger is the gradient between the source's coherence and the receiver's capacity. "
                + "A prepared vessel metabolizes contact as gnosis while an unprepared vessel can undergo "
                + "fragmentation or symbolic death.",
            "",
            "The face is the stable interface between the inner being and the social world. "
                + "Divine contact transforms that interface when the inherited identity cannot carry the revelation.",
        ].joined(separator: "\n")
        #expect(MarkdownReformatter.reformat(input) == expected)
    }

    @Test
    func `does not offer reflow for short intentional lines`() {
        let input = """
        First short line
        Second short line
        Third short line
        """

        #expect(!MarkdownReformatter.isLikelyReflowable(input))
    }

    @Test
    func `removes leading blank lines while preserving paragraph breaks`() {
        let input = [
            "",
            "   ",
            "The first paragraph is hard wrapped across a deliberately long line that should",
            "join cleanly without leaving whitespace before the pasted response.",
            "",
            "The second paragraph stays separate.",
        ].joined(separator: "\n")

        let expected = [
            "The first paragraph is hard wrapped across a deliberately long line that should "
                + "join cleanly without leaving whitespace before the pasted response.",
            "",
            "The second paragraph stays separate.",
        ].joined(separator: "\n")

        #expect(MarkdownReformatter.reformat(input) == expected)
    }

    @Test
    func `can preserve leading blank lines`() {
        let input = [
            "",
            "The first paragraph is hard wrapped across a deliberately long line that should",
            "join while retaining the leading blank line when that preference is disabled.",
        ].joined(separator: "\n")

        let expected = "\nThe first paragraph is hard wrapped across a deliberately long line that should "
            + "join while retaining the leading blank line when that preference is disabled."

        #expect(MarkdownReformatter.reformat(input, trimLeadingBlankLines: false) == expected)
    }

    @Test
    func `rejects structured text from automatic reflow`() {
        let yaml = """
        description: This configuration description is deliberately long enough to trigger prose detection
        enabled: true
        """
        let json = """
        {
          "description": "This configuration description is deliberately long enough to trigger prose detection",
          "enabled": true
        }
        """
        let toml = """
        description = "This configuration description is deliberately long enough to trigger prose detection"
        enabled = true
        """

        for input in [yaml, json, toml] {
            #expect(MarkdownReformatter.isLikelyReflowable(input))
            #expect(!MarkdownReformatter.isLikelyAutoReflowable(input))
        }
    }
}
