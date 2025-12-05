import AppKit
import Testing
import TrimmyCore
@testable import Trimmy

@MainActor
@Suite(.serialized)
struct ClipboardMonitorTests {
    @MainActor
    private final class StubAccessibilityPermission: AccessibilityPermissionChecking {
        var isTrusted: Bool
        init(isTrusted: Bool = true) { self.isTrusted = isTrusted }
    }

    @Test
    func clipboardTextIgnoresMarker() {
        let settings = AppSettings()
        let pasteboard = makeTestPasteboard()
        settings.autoTrimEnabled = true
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission())
        pasteboard.setString("echo hi\nls -la", forType: .string)
        _ = monitor.trimClipboardIfNeeded(force: false)
        #expect(monitor.clipboardText() != nil)
    }

    @Test
    func manualTrimReadsOwnMarker() {
        let settings = AppSettings()
        settings.autoTrimEnabled = false
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission())
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
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission())
        pasteboard.setString("single line", forType: .string)
        #expect(monitor.trimmedClipboardText(force: true) == "single line")
    }

    @Test
    func autoTrimDisabledDoesNotTrimDuringPolling() {
        let settings = AppSettings()
        settings.autoTrimEnabled = false
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission())

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
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission())

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
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission())

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
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission())

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
            pasteRestoreDelay: .milliseconds(0),
            pasteAction: {
                pasteTriggered = true
            },
            accessibilityPermission: StubAccessibilityPermission())

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
    func pasteFailsGracefullyWhenAccessibilityMissing() {
        let settings = AppSettings()
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            pasteRestoreDelay: .milliseconds(0),
            pasteAction: {},
            accessibilityPermission: StubAccessibilityPermission(isTrusted: false))

        pasteboard.setString("echo hi", forType: .string)
        let didPaste = monitor.pasteTrimmed()
        #expect(didPaste == false)
        #expect(monitor.lastSummary.contains("Accessibility"))
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
            pasteAction: {},
            accessibilityPermission: StubAccessibilityPermission())

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

    @Test
    func struckShowsWhitespaceRemoval() {
        let original = "foo  bar"
        let trimmed = "foo bar"

        let attributed = ClipboardMonitor.struck(original: original, trimmed: trimmed)
        let ns = NSAttributedString(attributed)

        // Visible-whitespace renderer turns spaces into "·". One of the dots should be struck.
        let rendered = ns.string
        #expect(rendered.contains("··"))

        var struckIndices: [Int] = []
        for idx in 0..<ns.length where ns.attribute(.strikethroughStyle, at: idx, effectiveRange: nil) != nil {
            struckIndices.append(idx)
        }

        #expect(struckIndices.count == 1)
        #expect((rendered as NSString).substring(with: NSRange(location: struckIndices[0], length: 1)) == "·")
    }

    @Test
    func struckHandlesTabsAndNewlines() {
        let original = "foo\tbar\nbaz"
        let trimmed = "foobar baz"

        let attributed = ClipboardMonitor.struck(original: original, trimmed: trimmed)
        let ns = NSAttributedString(attributed)
        let rendered = ns.string

        // Tabs turn to ⇥, newlines to ⏎
        #expect(rendered.contains("⇥"))
        #expect(rendered.contains("⏎"))

        var struckChars: [Character] = []
        for idx in 0..<ns.length where ns.attribute(.strikethroughStyle, at: idx, effectiveRange: nil) != nil {
            struckChars.append(Character((rendered as NSString).substring(with: NSRange(location: idx, length: 1))))
        }

        // Tab and newline should both be struck
        #expect(struckChars.contains("⇥"))
        #expect(struckChars.contains("⏎"))
    }
}
