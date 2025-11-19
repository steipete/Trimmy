import AppKit
import Testing
@testable import Trimmy

@MainActor
@Suite
struct PasteboardReadFallbackTests {
    @Test
    func readsStringWhenOnlyPublicTextAvailable() {
        let settings = AppSettings()
        let monitor = ClipboardMonitor(settings: settings)
        NSPasteboard.general.clearContents()
        let item = NSPasteboardItem()
        item.setString("hello from rtf", forType: NSPasteboard.PasteboardType("public.text"))
        NSPasteboard.general.writeObjects([item])
        #expect(monitor.clipboardText() == "hello from rtf")
    }
}
