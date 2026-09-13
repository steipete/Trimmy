import Testing
@testable import Trimmy

struct PreviewBadgeTests {
    @Test
    func `char count formats below one thousand`() {
        #expect(PreviewMetrics.prettyBadge(count: 0) == " · 0 chars")
        #expect(PreviewMetrics.prettyBadge(count: 999) == " · 999 chars")
    }

    @Test
    func `char count formats at and above one thousand`() {
        #expect(PreviewMetrics.prettyBadge(count: 1000) == " · 1.0k chars")
        #expect(PreviewMetrics.prettyBadge(count: 1234) == " · 1.2k chars")
        #expect(PreviewMetrics.prettyBadge(count: 10500) == " · 10k chars")
    }

    @Test
    func `pretty badge formats`() {
        #expect(PreviewMetrics.prettyBadge(count: 0) == " · 0 chars")
        #expect(PreviewMetrics.prettyBadge(count: 118) == " · 118 chars")
        #expect(PreviewMetrics.prettyBadge(count: 2500) == " · 2.5k chars")
    }

    @Test
    @MainActor
    func `summary ellipsizes long preview`() {
        let long = "0123456789ABCDEFGHIJKLMNOPQRSTUVWXYZ"
        // limit 20 -> head 9, tail 10, plus ellipsis
        let truncated = ClipboardMonitor.ellipsize(long, limit: 20)
        #expect(truncated == "012345678…QRSTUVWXYZ")
        #expect(truncated.count == 20)
    }

    @Test
    @MainActor
    func `summary does not ellipsize short preview`() {
        let text = "short preview"
        #expect(ClipboardMonitor.ellipsize(text, limit: 90) == text)
    }
}
