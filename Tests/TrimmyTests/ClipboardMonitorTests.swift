import AppKit
import Testing
@testable import Trimmy

@MainActor
@Suite(.serialized)
struct ClipboardMonitorTests {
    @Test
    func clipboardTextIgnoresMarker() {
        let settings = AppSettings()
        let pasteboard = makeTestPasteboard()
        settings.autoTrimEnabled = true
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)
        pasteboard.setString("echo hi\nls -la", forType: .string)
        _ = monitor.trimClipboardIfNeeded(force: false)
        #expect(monitor.clipboardText() != nil)
    }

    @Test
    func manualTrimReadsOwnMarker() {
        let settings = AppSettings()
        settings.autoTrimEnabled = false
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)
        pasteboard.setString("echo hi\nls -la", forType: .string)
        _ = monitor.trimClipboardIfNeeded(force: true)
        pasteboard.setString("echo hi\nls -la", forType: .string)
        let didTrimAgain = monitor.trimClipboardIfNeeded(force: true)
        #expect(didTrimAgain)
    }

    @Test
    func forceTrimReturnsRawWhenNotTransformed() {
        let settings = AppSettings()
        settings.autoTrimEnabled = false
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)
        pasteboard.setString("single line", forType: .string)
        #expect(monitor.trimmedClipboardText(force: true) == "single line")
    }

    @Test
    func autoTrimDisabledDoesNotTrimDuringPolling() {
        let settings = AppSettings()
        settings.autoTrimEnabled = false
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)

        pasteboard.setString(
            """
            echo hi \\
            ls -la
            """,
            forType: .string)

        let didTrim = monitor.trimClipboardIfNeeded()
        #expect(didTrim == false)
        let clipboard = pasteboard.string(forType: .string)
        #expect(clipboard?.contains(where: \.isNewline) == true)
    }

    @Test
    func disablingAutoTrimStopsFurtherAutomaticTrims() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)

        let first = """
        echo hi \\
        ls -la
        """
        pasteboard.setString(first, forType: .string)
        let firstTrimmed = monitor.trimClipboardIfNeeded()
        #expect(firstTrimmed == true)
        let afterFirst = pasteboard.string(forType: .string)
        #expect(afterFirst?.contains(where: \.isNewline) == false)

        settings.autoTrimEnabled = false

        let second = """
        echo bye \\
        pwd
        """
        pasteboard.setString(second, forType: .string)
        let secondTrimmed = monitor.trimClipboardIfNeeded()
        #expect(secondTrimmed == false)
        let afterSecond = pasteboard.string(forType: .string)
        #expect(afterSecond?.contains(where: \.isNewline) == true)
    }
}
