import AppKit
import Testing
@testable import Trimmy

@MainActor
@Suite(.serialized)
struct ManualTrimLastSummaryTests {
    @Test
    func `manual trim updates last even when not command`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = false
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)
        pasteboard.setString("just text", forType: .string)
        let didTrim = monitor.trimClipboardIfNeeded(force: true)
        #expect(didTrim)
        #expect(monitor.lastSummary.contains("just text"))
    }
}
