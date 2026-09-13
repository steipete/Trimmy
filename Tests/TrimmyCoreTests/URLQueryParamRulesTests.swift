import Testing
import TrimmyCore

struct URLQueryParamRulesTests {
    private static let defaultRules = URLQueryParamRules.parseCustomRules(URLQueryParamRules.defaultRulesText)

    @Test
    func `strips all query params from unknown domain`() {
        let cleaner = TextCleaner()
        #expect(cleaner
            .stripURLQueryParams("https://example.com/article?utm_source=twitter&utm_medium=social") ==
            "https://example.com/article")
    }

    @Test
    func `strips single query param`() {
        let cleaner = TextCleaner()
        #expect(cleaner
            .stripURLQueryParams("https://shop.example.com/product?ref=homepage") == "https://shop.example.com/product")
    }

    @Test
    func `returns nil when URL has no query params`() {
        let cleaner = TextCleaner()
        #expect(cleaner.stripURLQueryParams("https://example.com/article") == nil)
    }

    @Test
    func `ignores non URL text`() {
        let cleaner = TextCleaner()
        #expect(cleaner.stripURLQueryParams("just some text") == nil)
    }

    @Test
    func `ignores multiline text`() {
        let cleaner = TextCleaner()
        #expect(cleaner.stripURLQueryParams("https://example.com?foo=1\nhttps://other.com?bar=2") == nil)
    }

    @Test
    func `preserves URL path and fragment`() {
        let cleaner = TextCleaner()
        #expect(cleaner
            .stripURLQueryParams("https://example.com/path?utm_source=email#section") ==
            "https://example.com/path#section")
    }

    @Test
    func `works with http scheme`() {
        let cleaner = TextCleaner()
        #expect(cleaner.stripURLQueryParams("http://example.com/page?ref=old") == "http://example.com/page")
    }

    @Test
    func `returns nil when all params are in keeping set`() {
        let cleaner = TextCleaner()
        #expect(cleaner.stripURLQueryParams("https://example.com/watch?v=abc", keeping: ["v"]) == nil)
    }

    @Test
    func `keeps specified params and strips others`() {
        let cleaner = TextCleaner()
        let url = "https://example.com/watch?v=abc&utm_source=twitter"
        #expect(cleaner.stripURLQueryParams(url, keeping: ["v"]) == "https://example.com/watch?v=abc")
    }

    @Test
    func `preserves percent encoding in kept params`() {
        let cleaner = TextCleaner()
        let url = "https://example.com/file?node-id=42%3A1&ref=foo"
        #expect(cleaner.stripURLQueryParams(url, keeping: ["node-id"]) == "https://example.com/file?node-id=42%3A1")
    }

    @Test
    func `default rules include youtube`() {
        let keeping = URLQueryParamRules.keepParams(for: "www.youtube.com", customRules: Self.defaultRules)
        #expect(keeping == ["v", "list", "t"])
    }

    @Test
    func `host matching is case insensitive`() {
        let keeping = URLQueryParamRules.keepParams(for: "WWW.YouTube.COM", customRules: Self.defaultRules)
        #expect(keeping == ["v", "list", "t"])
    }

    @Test
    func `default rules include youtu be`() {
        let keeping = URLQueryParamRules.keepParams(for: "youtu.be", customRules: Self.defaultRules)
        #expect(keeping == ["t"])
    }

    @Test
    func `unknown domain has empty keeplist`() {
        let keeping = URLQueryParamRules.keepParams(for: "example.com", customRules: Self.defaultRules)
        #expect(keeping.isEmpty)
    }

    @Test
    func `youtube strips tracking and keeps video id`() {
        let keeping = URLQueryParamRules.keepParams(for: "www.youtube.com", customRules: Self.defaultRules)
        let cleaner = TextCleaner()
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&utm_source=twitter"
        #expect(cleaner.stripURLQueryParams(url, keeping: keeping) == "https://www.youtube.com/watch?v=dQw4w9WgXcQ")
    }

    @Test
    func `youtube keeps timestamp alongside video id`() {
        let keeping = URLQueryParamRules.keepParams(for: "www.youtube.com", customRules: Self.defaultRules)
        let cleaner = TextCleaner()
        let url = "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=142&utm_campaign=viral"
        #expect(cleaner
            .stripURLQueryParams(url, keeping: keeping) == "https://www.youtube.com/watch?v=dQw4w9WgXcQ&t=142")
    }

    @Test
    func `youtube returns nil when only kept params present`() {
        let keeping = URLQueryParamRules.keepParams(for: "www.youtube.com", customRules: Self.defaultRules)
        let cleaner = TextCleaner()
        #expect(cleaner.stripURLQueryParams("https://www.youtube.com/watch?v=dQw4w9WgXcQ", keeping: keeping) == nil)
    }

    @Test
    func `youtu be keeps timestamp strips tracking`() {
        let keeping = URLQueryParamRules.keepParams(for: "youtu.be", customRules: Self.defaultRules)
        let cleaner = TextCleaner()
        let url = "https://youtu.be/dQw4w9WgXcQ?t=42&si=trackingparam"
        #expect(cleaner.stripURLQueryParams(url, keeping: keeping) == "https://youtu.be/dQw4w9WgXcQ?t=42")
    }

    @Test
    func `google docs keeps tab param`() {
        let keeping = URLQueryParamRules.keepParams(for: "docs.google.com", customRules: Self.defaultRules)
        let cleaner = TextCleaner()
        let url = "https://docs.google.com/document/d/1ABC/edit?tab=t.0&usp=sharing"
        #expect(cleaner
            .stripURLQueryParams(url, keeping: keeping) == "https://docs.google.com/document/d/1ABC/edit?tab=t.0")
    }

    @Test
    func `github keeps tab param`() {
        let keeping = URLQueryParamRules.keepParams(for: "github.com", customRules: Self.defaultRules)
        let cleaner = TextCleaner()
        let url = "https://github.com/steipete/Trimmy?tab=issues&foo=bar"
        #expect(cleaner.stripURLQueryParams(url, keeping: keeping) == "https://github.com/steipete/Trimmy?tab=issues")
    }

    @Test
    func `figma keeps node id and preserves encoding`() {
        let keeping = URLQueryParamRules.keepParams(for: "www.figma.com", customRules: Self.defaultRules)
        let cleaner = TextCleaner()
        let url = "https://www.figma.com/file/abc123/Design?node-id=42%3A1&ref=something"
        #expect(cleaner
            .stripURLQueryParams(url, keeping: keeping) == "https://www.figma.com/file/abc123/Design?node-id=42%3A1")
    }

    @Test
    func `custom rules override domain`() {
        let rules = URLQueryParamRules.parseCustomRules("youtube.com: myParam")
        let keeping = URLQueryParamRules.keepParams(for: "www.youtube.com", customRules: rules)
        #expect(keeping == ["myParam"])
    }

    @Test
    func `custom rules apply to unlisted domains`() {
        let rules = URLQueryParamRules.parseCustomRules("myapp.internal: id")
        let keeping = URLQueryParamRules.keepParams(for: "myapp.internal", customRules: rules)
        #expect(keeping == ["id"])
    }

    @Test
    func `parses custom rules with extra whitespace`() {
        let rules = URLQueryParamRules.parseCustomRules("  example.com : foo , bar  \nother.io: baz")
        #expect(rules.count == 2)
        #expect(rules[0].domain == "example.com")
        #expect(rules[0].keepParams == ["foo", "bar"])
        #expect(rules[1].domain == "other.io")
        #expect(rules[1].keepParams == ["baz"])
    }

    @Test
    func `ignores blank lines and malformed rules`() {
        let rules = URLQueryParamRules.parseCustomRules("\nexample.com: v\n\nnodomain\n")
        #expect(rules.count == 1)
        #expect(rules[0].domain == "example.com")
    }

    @Test
    func `default rules text round trips through parser`() {
        let rules = URLQueryParamRules.parseCustomRules(URLQueryParamRules.defaultRulesText)
        #expect(rules.count == URLQueryParamRules.builtIn.count)
    }
}
