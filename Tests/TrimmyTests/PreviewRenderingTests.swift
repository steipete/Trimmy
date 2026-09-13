import AppKit
import Testing
@testable import Trimmy

@MainActor
struct PreviewRenderingTests {
    @Test(arguments: ["😀", "e\u{301}", "👨‍👩‍👧‍👦"])
    func `strikes whole removed characters after Unicode`(prefix: String) {
        let preview = NSAttributedString(ClipboardMonitor.struck(original: prefix + "x y", trimmed: prefix + "y"))
        let prefixLength = prefix.utf16.count
        for index in 0..<preview.length {
            let removed = preview.attribute(.strikethroughStyle, at: index, effectiveRange: nil) != nil
            #expect(removed == (index == prefixLength || index == prefixLength + 1))
        }
    }

    @Test
    func `inserted quotes do not strike surviving path text`() {
        let preview = NSAttributedString(ClipboardMonitor.struck(
            original: "/tmp/My File", trimmed: "\"/tmp/My File\""))
        for index in 0..<preview.length {
            #expect(preview.attribute(.strikethroughStyle, at: index, effectiveRange: nil) == nil)
        }
    }

    @Test
    func `settings preview strips prompts like actual cleanup`() {
        let preview = AggressivenessPreviewEngine.previewAfter(
            for: "$ echo hello\n$ echo world", level: .normal, preserveBlankLines: false, removeBoxDrawing: true)
        #expect(preview == "echo hello echo world")
    }

    @Test
    func `settings preview preserves a list like actual cleanup`() {
        let preview = AggressivenessPreviewEngine.previewAfter(
            for: "apples\npears\nbananas", level: .high, preserveBlankLines: false, removeBoxDrawing: true)
        #expect(preview == "apples\npears\nbananas")
    }
}
