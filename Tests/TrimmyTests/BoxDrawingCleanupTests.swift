import Testing
@testable import Trimmy

@Suite
struct BoxDrawingCleanupTests {
    @Test
    func removesBoxDrawingAfterPipe() {
        let input = "curl -I https://example.com | │ head -n 5"
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == "curl -I https://example.com | head -n 5")
    }

    @Test
    func collapsesMultipleBoxDrawingAfterPipe() {
        let input = "cmd | │ │ grep foo"
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == "cmd | grep foo")
    }

    @Test
    func removesBoxDrawingInsertedByTerminalWrap() {
        let input =
            "curl -I https://github.com/steipete/Trimmy/releases/ │ download/v0.4.5/Trimmy-0.4.5.zip | head -n 5"
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        #expect(cleaned
            == "curl -I https://github.com/steipete/Trimmy/releases/download/v0.4.5/Trimmy-0.4.5.zip | head -n 5")
    }

    @Test
    func leavesBarsWhenNoPipePresent() {
        let input = "│ this line has decoration but no pipe"
        // Even without a pipe, lone box glyphs should be stripped.
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == "this line has decoration but no pipe")
    }

    @Test
    func preservesLegitPipesWithoutBoxDrawing() {
        let input = "curl -I https://example.com | head -n 5"
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == nil, "No box glyphs present → no change")
    }

    @Test
    func dedentsResidualWhitespaceAfterBoxCharRemoval() {
        let input = "│  Sehr geehrtes Netcup-Team,\n│  \n│  ich möchte für meinen Managed Server"
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == "Sehr geehrtes Netcup-Team,\n\nich möchte für meinen Managed Server")
    }

    @Test
    func dedentsPreservesRelativeIndentation() {
        let input = "│  line one\n│      indented\n│  line three"
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        // After box-char removal: " line one", "     indented", " line three"
        // Dedent by 1 (min common indent): "line one", "    indented", "line three"
        // Stage 5 collapses 4 spaces to 1, so final: "line one", " indented", "line three"
        #expect(cleaned == "line one\n indented\nline three")
    }

    @Test
    func dedentOnlyAffectsLinesWithBoxChars() {
        // Mixed content: majority has box chars, one plain line with intentional indent
        let input = "│  line one\n│  line two\n│  line three\n plain line"
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        // Box-char lines get dedented; the plain line keeps its original indent
        #expect(cleaned?.contains(" plain line") == true, "Plain line indent must be preserved")
    }

    @Test
    func preservesIndentationWhenNoBoxDrawing() {
        let input = """
        {
          \"Version\": \"2012-10-17\",
          \"Statement\": [
            { \"Effect\": \"Allow\" }
          ]
        }
        """
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == nil, "No box glyphs present → keep original spacing")
    }
}
