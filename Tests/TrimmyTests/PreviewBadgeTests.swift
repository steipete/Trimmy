import Testing
@testable import Trimmy

@Suite
struct PreviewBadgeTests {
    @Test
    func formatsBelowOneThousand() {
        #expect(PreviewMetrics.charCountSuffix(count: 0) == " (0 chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 999) == " (999 chars)")
    }

    @Test
    func formatsAtAndAboveOneThousand() {
        #expect(PreviewMetrics.charCountSuffix(count: 1000) == " (1.0k chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 1234) == " (1.2k chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 10500) == " (10k chars)")
    }

    @Test
    func includesTruncationCountWhenLimited() {
        #expect(PreviewMetrics.charCountSuffix(count: 49, limit: 50) == " (49 chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 50, limit: 50) == " (50 chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 51, limit: 50) == " (51 chars, 1 truncations)")
        #expect(PreviewMetrics.charCountSuffix(count: 149, limit: 50) == " (149 chars, 2 truncations)")
        #expect(PreviewMetrics.charCountSuffix(count: 2500, limit: 50) == " (2.5k chars, 49 truncations)")
    }

    @Test
    func suppressesTruncationsWhenAsked() {
        #expect(PreviewMetrics.charCountSuffix(count: 149, limit: 50, showTruncations: false) == " (149 chars)")
        #expect(PreviewMetrics.charCountSuffix(count: 2500, limit: 50, showTruncations: false) == " (2.5k chars)")
    }
}
