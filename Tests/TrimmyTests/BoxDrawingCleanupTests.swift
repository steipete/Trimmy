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
