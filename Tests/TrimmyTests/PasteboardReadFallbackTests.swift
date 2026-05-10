import AppKit
import Testing
@testable import Trimmy

@MainActor
@Suite(.serialized)
struct PasteboardReadFallbackTests {
    @Test
    func `reads string when only public text available`() {
        let settings = AppSettings()
        settings.usePasteboardFallbacks = true
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)
        let item = NSPasteboardItem()
        item.setString("hello from rtf", forType: NSPasteboard.PasteboardType("public.text"))
        pasteboard.writeObjects([item])
        #expect(monitor.clipboardText() == "hello from rtf")
    }

    @Test
    func `defaults leave fallbacks off`() {
        let settings = AppSettings()
        settings.usePasteboardFallbacks = false
        #expect(settings.usePasteboardFallbacks == false)
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)
        let item = NSPasteboardItem()
        item.setString("hello from rtf", forType: NSPasteboard.PasteboardType("public.text"))
        pasteboard.writeObjects([item])
        #expect(monitor.clipboardText() == nil)
    }
}
