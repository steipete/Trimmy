import Testing
@testable import Trimmy

struct PreviewBadgeTests {
    @Test
    func `formats below one thousand`() {
        #expect(PreviewMetrics.charCountSuffix(count: 0) == " (0 chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 999) == " (999 chars)")
    }

    @Test
    func `formats at and above one thousand`() {
        #expect(PreviewMetrics.charCountSuffix(count: 1000) == " (1.0k chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 1234) == " (1.2k chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 10500) == " (10k chars)")
    }

    @Test
    func `includes truncation count when limited`() {
        #expect(PreviewMetrics.charCountSuffix(count: 49, limit: 50) == " (49 chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 50, limit: 50) == " (50 chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 51, limit: 50) == " (51 chars, 1 truncations)")
        #expect(PreviewMetrics.charCountSuffix(count: 149, limit: 50) == " (149 chars, 2 truncations)")
        #expect(PreviewMetrics.charCountSuffix(count: 2500, limit: 50) == " (2.5k chars, 49 truncations)")
    }

    @Test
    func `suppresses truncations when asked`() {
        #expect(PreviewMetrics.charCountSuffix(count: 149, limit: 50, showTruncations: false) == " (149 chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 2500, limit: 50, showTruncations: false) == " (2.5k chars)")
    }

    @Test
    func `pretty badge formats`() {
        #expect(PreviewMetrics.prettyBadge(count: 118, limit: 50, showTruncations: false) == " · 118 chars")
        #expect(PreviewMetrics.prettyBadge(count: 118, limit: 50, showTruncations: true) == " · 118 chars · 2 trimmed")
        #expect(PreviewMetrics
            .prettyBadge(count: 2500, limit: 50, showTruncations: true) == " · 2.5k chars · 49 trimmed")
    }
}
