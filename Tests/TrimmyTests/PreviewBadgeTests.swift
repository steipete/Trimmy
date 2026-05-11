import Testing
@testable import Trimmy

struct PreviewBadgeTests {
    @Test
    func `char count formats below one thousand`() {
        #expect(PreviewMetrics.charCountSuffix(count: 0) == " (0 chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 999) == " (999 chars)")
    }

    @Test
    func `char count formats at and above one thousand`() {
        #expect(PreviewMetrics.charCountSuffix(count: 1000) == " (1.0k chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 1234) == " (1.2k chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 10500) == " (10k chars)")
    }

    @Test
    func `pretty badge formats`() {
        #expect(PreviewMetrics.prettyBadge(count: 0) == " · 0 chars")
        #expect(PreviewMetrics.prettyBadge(count: 118) == " · 118 chars")
        #expect(PreviewMetrics.prettyBadge(count: 2500) == " · 2.5k chars")
    }
}
