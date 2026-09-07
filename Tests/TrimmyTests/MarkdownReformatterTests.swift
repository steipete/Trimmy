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

        #expect(MarkdownReformatter.reformat(input, trimLeadingBlankLines: true) == expected)
    }

    @Test
    func `preserves leading blank lines by default`() {
        let input = [
            "",
            "The first paragraph is hard wrapped across a deliberately long line that should",
            "join while retaining the leading blank line when that preference is disabled.",
        ].joined(separator: "\n")

        let expected = "\nThe first paragraph is hard wrapped across a deliberately long line that should "
            + "join while retaining the leading blank line when that preference is disabled."

        #expect(MarkdownReformatter.reformat(input) == expected)
    }

    @Test
    func `rejects structured text from manual and automatic reflow`() {
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
        let yamlLiteralBlock = """
        description: |
          This configuration description is deliberately long enough to trigger prose detection
          while remaining valid YAML that must retain its line breaks.
        """
        let yamlFoldedBlock = """
        description: >-
          This configuration description is deliberately long enough to trigger prose detection
          while remaining valid YAML that must retain its folding semantics.
        """

        for input in [yaml, json, toml, yamlLiteralBlock, yamlFoldedBlock] {
            #expect(!MarkdownReformatter.isLikelyReflowable(input))
        }
    }

    @Test(arguments: [
        "func showMessageToUser(_ message: String) {\n"
            + "    // Keep this comment separate from the call.\n    print(message)\n}",
        "def show_message_to_user(message_with_a_long_name):\n    print(message_with_a_long_name)",
        "const message = 'This is a deliberately long string in JavaScript';\nconsole.log(message);",
        "description = \"\"\"This is a deliberately long TOML string\nwith another line inside the string.\"\"\"",
        "description: &anchor |\n  This is a deliberately long YAML scalar line\n  whose indentation must stay intact.",
        "\"\"\"\nThis is a deliberately long multiline string literal\nwith a meaningful newline.\n\"\"\"",
        "r'''\nThis is a deliberately long raw Python string literal\nwith a meaningful newline.\n'''",
        "description:\n  This is a deliberately long YAML plain scalar value\n"
            + "  that spans two lines.\nenabled:\n  true",
        "display name: This is a deliberately long YAML value\nenabled: true",
        "説明: This is a deliberately long YAML value that must keep its newline\n有効: true",
        "123: This is a deliberately long YAML value that must keep its newline\n456: true",
        "-- This comment is deliberately long enough to resemble wrapped prose\n"
            + "SELECT first_name, last_name FROM users",
    ])
    func `rejects unfenced source and multiline configuration`(input: String) {
        #expect(!MarkdownReformatter.isLikelyReflowable(input))
    }

    @Test(arguments: [
        "A deliberately long column heading | Another column\n--- | ---\none | two",
        "A deliberately long column heading | Another column\n:--- | ---:\none | two",
        "> This quotation is deliberately long enough to look like wrapped prose\n"
            + "> but its markers must remain intact.",
        "This is a deliberately long heading in the setext style\n"
            + "=====================================================",
    ])
    func `does not flatten unsupported Markdown block structures`(input: String) {
        #expect(!MarkdownReformatter.isLikelyReflowable(input))
    }

    @Test
    func `wrapped URLs stay out of prose reflow`() {
        let input = "https://example.com/a-deliberately-long-path\nsegment"
        #expect(!MarkdownReformatter.isLikelyReflowable(input))
    }

    @Test(arguments: [
        "For more details, consult the documentation at https://example.com/a-deliberately-long-path\nsegment",
        "For more details, consult the [documentation](a-deliberately-long-path/\nsegment)",
    ])
    func `inline link continuations stay out of prose reflow`(input: String) {
        #expect(!MarkdownReformatter.isLikelyReflowable(input))
    }

    @Test(arguments: [
        "name,description,enabled\nexample,A deliberately long description with many words,true\n"
            + "other,Another value,false",
        "name\tdescription\tenabled\nexample\tA deliberately long description with many words\ttrue",
        "1,\"This field is deliberately long enough to resemble wrapped prose\nand intentionally continues here\",true",
        "name, description, enabled\nexample, A deliberately long description with many words, true",
        "1, A deliberately long description with many words, true\n"
            + "2, Another deliberately long description with many words, false",
        "Alice, A deliberately long description with several words\n"
            + "Bob, Another deliberately long description with several words",
        "John Doe, This field contains enough ordinary words to exceed forty characters\n"
            + "Jane Doe, Another field contains enough ordinary words to exceed forty characters",
        "\"first\",\"A quoted description, with deliberately many words\"\n\"second\",\"Another description\"",
        "│ This terminal output has enough words to resemble a prose paragraph\n│ but these rows must remain separate",
        "0123456789abcdef0123456789abcdef0123456789abcdef\n0123456789abcdef0123456789abcdef0123456789abcdef",
    ])
    func `rejects delimited records and terminal rows`(input: String) {
        #expect(!MarkdownReformatter.isLikelyReflowable(input))
    }

    @Test
    func `ordinary commas on consecutive prose lines are not CSV`() {
        let input = "This is an ordinary wrapped paragraph, with enough words on the first line\n"
            + "and this line has another comma, followed by more ordinary prose\n"
            + "that should be joined."
        #expect(MarkdownReformatter.isLikelyReflowable(input))
        #expect(MarkdownReformatter.reformat(input) == input.replacingOccurrences(of: "\n", with: " "))
    }

    @Test
    func `indented code is excluded without blocking list continuations`() {
        let code = "    This output line is deliberately long enough to look like a prose paragraph\n"
            + "    These words are still part of an indented code block."
        #expect(!MarkdownReformatter.isLikelyReflowable(code))
        #expect(!MarkdownReformatter.isLikelyReflowable("# Output\n" + code))
        let list = "- This list item is deliberately wrapped across a long line\n"
            + "    and continues with four spaces of indentation.\n- Another item."
        #expect(MarkdownReformatter.isLikelyReflowable(list))
        #expect(MarkdownReformatter.reformat(list) == "- This list item is deliberately wrapped across a long line "
            + "and continues with four spaces of indentation.\n- Another item.")
    }

    @Test(arguments: ["```", "~~~~"])
    func `reflows prose around fenced configuration and source`(fence: String) {
        let prose = "This paragraph is deliberately long enough to be recognized as wrapped prose"
        let example = "\(fence)yaml\ndescription: |\n  literal content\nenabled: true\n\(fence)"
        let input = "\(prose)\nand this is its continuation.\n\n\(example)"
        #expect(MarkdownReformatter.isLikelyReflowable(input))
        #expect(MarkdownReformatter.reformat(input) == "\(prose) and this is its continuation.\n\n\(example)")
    }
}
