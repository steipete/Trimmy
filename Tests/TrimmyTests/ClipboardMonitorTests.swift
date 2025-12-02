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

    @Test
    func repairsWrappedURLEvenWhenAggressivenessIsLow() {
        let settings = AppSettings()
        settings.aggressiveness = .low
        settings.autoTrimEnabled = true
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)

        let expectedURL =
            "https://github.blog/changelog/2025-07-14-"
                + "pkce-support-for-oauth-and-github-app-authentication?utm_source=openai"

        pasteboard.setString(
            """
            https://github.blog/changelog/2025-07-14-
            pkce-support-for-oauth-and-github-app-authentication?utm_source=openai
            """,
            forType: .string)

        let didTrim = monitor.trimClipboardIfNeeded(force: false)
        #expect(didTrim)
        #expect(pasteboard.string(forType: .string) == expectedURL)
    }

    @Test
    func leavesMultipleSeparateUrlsUntouched() {
        let settings = AppSettings()
        settings.aggressiveness = .low
        settings.autoTrimEnabled = true
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)

        let twoUrls = """
        https://example.com/foo
        https://example.com/bar
        """
        pasteboard.setString(twoUrls, forType: .string)

        let didTrim = monitor.trimClipboardIfNeeded(force: false)
        #expect(didTrim == false)
        #expect(pasteboard.string(forType: .string) == twoUrls)
    }

    @Test
    func pasteTrimmedKeepsOriginalForLater() {
        let settings = AppSettings()
        settings.autoTrimEnabled = false
        var pasteTriggered = false
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            pasteRestoreDelay: .milliseconds(0))
        {
            pasteTriggered = true
        }

        pasteboard.setString(
            """
            echo hi \\
            ls -la
            """,
            forType: .string)

        let didPaste = monitor.pasteTrimmed()
        #expect(didPaste)
        #expect(pasteTriggered)

        let didPasteOriginal = monitor.pasteOriginal()
        #expect(didPasteOriginal)
        #expect(monitor.lastSummary.contains("echo hi"))
    }

    @Test
    func pasteOriginalUsesCachedPreTrimCopy() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            pasteRestoreDelay: .milliseconds(0),
            pasteAction: {})

        let original = """
        echo hi \\
        ls -la
        """
        pasteboard.setString(original, forType: .string)
        _ = monitor.trimClipboardIfNeeded() // auto-trim saves original, writes trimmed

        let didPasteOriginal = monitor.pasteOriginal()
        #expect(didPasteOriginal)
        #expect(monitor.lastSummary.contains("echo hi"))
    }

    @Test
    func struckMarksRemovedDecorativePipe() {
        let original = "foo │ bar | baz"
        let trimmed = "foo bar | baz"

        let attributed = ClipboardMonitor.struck(original: original, trimmed: trimmed)
        let ns = NSAttributedString(attributed)

        let decorativeRange = (original as NSString).range(of: "│")
        #expect(decorativeRange.location != NSNotFound)

        let strike = ns.attribute(.strikethroughStyle, at: decorativeRange.location, effectiveRange: nil) as? Int
        #expect(strike == NSUnderlineStyle.single.rawValue)
    }

    @Test
    func struckDoesNotStrikeSurvivingPipe() {
        let original = "foo │ bar | baz"
        let trimmed = "foo bar | baz"

        let attributed = ClipboardMonitor.struck(original: original, trimmed: trimmed)
        let ns = NSAttributedString(attributed)

        let pipeRange = (original as NSString).range(of: "| baz")
        #expect(pipeRange.location != NSNotFound)

        let strike = ns.attribute(.strikethroughStyle, at: pipeRange.location, effectiveRange: nil) as? Int
        #expect(strike == nil)
    }
}
