import Testing
import TrimmyCore

struct BoxDrawingCleanupTests {
    @Test
    func `removes box drawing after pipe`() {
        let input = "curl -I https://example.com | │ head -n 5"
        let cleaned = TextCleaner.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == "curl -I https://example.com | head -n 5")
    }

    @Test
    func `collapses multiple box drawing after pipe`() {
        let input = "cmd | │ │ grep foo"
        let cleaned = TextCleaner.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == "cmd | grep foo")
    }

    @Test
    func `removes box drawing inserted by terminal wrap`() {
        let input =
            "curl -I https://github.com/steipete/Trimmy/releases/ │ download/v0.4.5/Trimmy-0.4.5.zip | head -n 5"
        let cleaned = TextCleaner.stripBoxDrawingCharacters(in: input)
        #expect(cleaned
            == "curl -I https://github.com/steipete/Trimmy/releases/download/v0.4.5/Trimmy-0.4.5.zip | head -n 5")
    }

    @Test
    func `leaves bars when no pipe present`() {
        let input = "│ this line has decoration but no pipe"
        // Even without a pipe, lone box glyphs should be stripped.
        let cleaned = TextCleaner.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == "this line has decoration but no pipe")
    }

    @Test
    func `preserves legit pipes without box drawing`() {
        let input = "curl -I https://example.com | head -n 5"
        let cleaned = TextCleaner.stripBoxDrawingCharacters(in: input)
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
        let cleaned = TextCleaner.stripBoxDrawingCharacters(in: input)
        #expect(cleaned == nil, "No box glyphs present → keep original spacing")
    }

    @Test
    func `a box drawing line does not delete surrounding newlines`() {
        let cleaned = TextCleaner.stripBoxDrawingCharacters(in: "keep\n\n│\n\nlines")
        #expect(cleaned == "keep\n\n \n\nlines")
    }

    @Test(arguments: ["\r", "\n", "\r\n", "\u{0085}", "\u{2028}", "\u{2029}"])
    func `gutter cleanup preserves all line separators`(separator: String) {
        let input = "keep\(separator)│\(separator)lines"
        #expect(TextCleaner.stripBoxDrawingCharacters(in: input) == "keep\(separator) \(separator)lines")
    }

    @Test
    func `a gutter at the start of a line keeps the line break`() {
        let cleaned = TextCleaner.stripBoxDrawingCharacters(in: "intro\n│ alpha\noutro")
        #expect(cleaned == "intro\n alpha\noutro")
    }

    @Test
    func `a colon label keeps a space before the next word`() {
        let cleaned = TextCleaner.stripBoxDrawingCharacters(in: "Note: │ hello")
        #expect(cleaned == "Note: hello")
    }

    @Test
    func `a nonbreaking space around a gutter is still removed`() {
        let cleaned = TextCleaner.stripBoxDrawingCharacters(in: "curl |\u{00A0}│\u{00A0}head")
        #expect(cleaned == "curl | head")
    }

    @Test
    func `a uri colon still joins across a gutter`() {
        #expect(TextCleaner.stripBoxDrawingCharacters(in: "mailto: │ user@example.com") ==
            "mailto:user@example.com")
        #expect(TextCleaner.stripBoxDrawingCharacters(in: "git clone git@example.com: │ org/repo.git") ==
            "git clone git@example.com:org/repo.git")
        #expect(TextCleaner.stripBoxDrawingCharacters(in: "git clone example.com: │ org/repo.git") ==
            "git clone example.com:org/repo.git")
        #expect(TextCleaner.stripBoxDrawingCharacters(in: "git clone example.com: │ repo.git") ==
            "git clone example.com:repo.git")
        #expect(TextCleaner.stripBoxDrawingCharacters(in: "git clone buildbox: │ org/repo.git") ==
            "git clone buildbox:org/repo.git")
        #expect(TextCleaner.stripBoxDrawingCharacters(in: "git clone buildbox: │ repo") ==
            "git clone buildbox:repo")
        #expect(TextCleaner.stripBoxDrawingCharacters(in: "git clone EXAMPLE.COM: │ repo.git") ==
            "git clone EXAMPLE.COM:repo.git")
        #expect(TextCleaner.stripBoxDrawingCharacters(in: "git clone BUILDBOX: │ repo") ==
            "git clone BUILDBOX:repo")
        #expect(TextCleaner.stripBoxDrawingCharacters(in: "git clone git@[2001:db8::1]: │ repo") ==
            "git clone git@[2001:db8::1]:repo")
    }

    @Test(arguments: [
        ("git clone BuildBox: │ repo", "git clone BuildBox:repo"),
        ("git clone --depth 1 BuIlDBox: │ repo", "git clone --depth 1 BuIlDBox:repo"),
        ("scp local.txt BuildBox: │ remote.txt", "scp local.txt BuildBox:remote.txt"),
        ("rsync local.txt BuildBox: │ remote.txt", "rsync local.txt BuildBox:remote.txt"),
    ])
    func `joins mixed case remote hosts in command context`(input: String, expected: String) {
        #expect(TextCleaner.stripBoxDrawingCharacters(in: input) == expected)
    }
}
