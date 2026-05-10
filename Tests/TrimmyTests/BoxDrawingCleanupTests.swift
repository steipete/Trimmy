import Testing
@testable import Trimmy

struct BoxDrawingCleanupTests {
    @Test
    func `removes box drawing after pipe`() {
        let input = "curl -I https://example.com | │ head -n 5"
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == "curl -I https://example.com | head -n 5")
    }

    @Test
    func `collapses multiple box drawing after pipe`() {
        let input = "cmd | │ │ grep foo"
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == "cmd | grep foo")
    }

    @Test
    func `removes box drawing inserted by terminal wrap`() {
        let input =
            "curl -I https://github.com/steipete/Trimmy/releases/ │ download/v0.4.5/Trimmy-0.4.5.zip | head -n 5"
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        #expect(cleaned
            == "curl -I https://github.com/steipete/Trimmy/releases/download/v0.4.5/Trimmy-0.4.5.zip | head -n 5")
    }

    @Test
    func `leaves bars when no pipe present`() {
        let input = "│ this line has decoration but no pipe"
        // Even without a pipe, lone box glyphs should be stripped.
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == "this line has decoration but no pipe")
    }

    @Test
    func `preserves legit pipes without box drawing`() {
        let input = "curl -I https://example.com | head -n 5"
        let cleaned = CommandDetector.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == nil, "No box glyphs present → no change")
    }

    @Test
    func `preserves indentation when no box drawing`() {
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
