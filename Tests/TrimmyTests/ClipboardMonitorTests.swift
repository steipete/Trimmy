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
        init(isTrusted: Bool = true) {
            self.isTrusted = isTrusted
        }
    }

    private final class StubBrowserLocationProvider: BrowserLocationProviding {
        let host: String?
        private(set) var callCount = 0

        func currentHost(for _: ClipboardSourceContext) -> String? {
            self.callCount += 1
            return self.host
        }

        init(host: String?) {
            self.host = host
        }
    }

    @Test
    func `clipboard text ignores marker`() {
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

    @Test(arguments: [
        "description: |\n  This paragraph belongs to a YAML scalar.\n  Its indentation is required.",
        "art: |\n  │ hello\n  │ world",
        "script: &anchor |\n  $ echo one\n  $ echo two",
        "description: !!str |\n  This paragraph belongs to a YAML scalar.\n  Its indentation is required.",
    ])
    func `automatic trimming preserves YAML literal indentation`(input: String) {
        let settings = AppSettings()
        let originalAutoTrim = settings.autoTrimEnabled
        let originalContextAware = settings.contextAwareTrimmingEnabled
        let originalAggressiveness = settings.generalAggressiveness
        defer {
            settings.autoTrimEnabled = originalAutoTrim
            settings.contextAwareTrimmingEnabled = originalContextAware
            settings.generalAggressiveness = originalAggressiveness
        }
        settings.autoTrimEnabled = true
        settings.contextAwareTrimmingEnabled = false
        for aggressiveness in [GeneralAggressiveness.none, .low, .normal] {
            settings.generalAggressiveness = aggressiveness
            let pasteboard = makeTestPasteboard()
            let monitor = ClipboardMonitor(
                settings: settings,
                pasteboard: pasteboard,
                accessibilityPermission: StubAccessibilityPermission())
            pasteboard.setString(input, forType: .string)
            #expect(!monitor.trimClipboardIfNeeded(force: false))
            #expect(pasteboard.string(forType: .string) == input)
        }
    }

    @Test
    func `manual trim reads own marker`() {
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
    func `force trim returns raw when not transformed`() {
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
    func `auto trim disabled does not trim during polling`() {
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
    func `auto trim skips excluded app source`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.autoTrimExcludedApps = "com.openai.chat"
        defer { settings.autoTrimExcludedApps = "" }
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission())
        let sourceContext = ClipboardSourceContext(
            timestamp: Date(),
            capture: .eventTap,
            bundleIdentifier: "com.openai.chat",
            appName: "ChatGPT",
            processIdentifier: nil)

        pasteboard.setString(
            """
            echo hi \\
            ls -la
            """,
            forType: .string)

        let didTrim = monitor.trimClipboardIfNeeded(force: false, sourceContext: sourceContext)
        #expect(didTrim == false)
        #expect(pasteboard.string(forType: .string)?.contains(where: \.isNewline) == true)
        #expect(monitor.lastSummary.contains("Auto-trim skipped"))
    }

    @Test
    func `app exclusion skips browser location lookup`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.autoTrimExcludedApps = "Google Chrome"
        settings.autoTrimExcludedSites = "example.com"
        defer {
            settings.autoTrimExcludedApps = ""
            settings.autoTrimExcludedSites = ""
        }
        let pasteboard = makeTestPasteboard()
        let browserLocationProvider = StubBrowserLocationProvider(host: "example.com")
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission(),
            browserLocationProvider: browserLocationProvider)
        let sourceContext = ClipboardSourceContext(
            timestamp: Date(),
            capture: .eventTap,
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            processIdentifier: nil)

        pasteboard.setString(
            """
            echo hi \\
            ls -la
            """,
            forType: .string)

        #expect(monitor.trimClipboardIfNeeded(force: false, sourceContext: sourceContext) == false)
        #expect(browserLocationProvider.callCount == 0)
    }

    @Test
    func `manual trim still works for excluded app source`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.autoTrimExcludedApps = "ChatGPT"
        defer { settings.autoTrimExcludedApps = "" }
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission())
        let sourceContext = ClipboardSourceContext(
            timestamp: Date(),
            capture: .eventTap,
            bundleIdentifier: "com.openai.chat",
            appName: "ChatGPT",
            processIdentifier: nil)

        pasteboard.setString(
            """
            echo hi \\
            ls -la
            """,
            forType: .string)

        let didTrim = monitor.trimClipboardIfNeeded(force: true, sourceContext: sourceContext)
        #expect(didTrim)
        #expect(pasteboard.string(forType: .string)?.contains(where: \.isNewline) == false)
    }

    @Test
    func `excluded auto trim refreshes manual paste cache`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.autoTrimExcludedApps = "ChatGPT"
        defer { settings.autoTrimExcludedApps = "" }
        var pasteTriggered = false
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            pasteRestoreDelay: .seconds(60),
            pasteAction: { pasteTriggered = true },
            accessibilityPermission: StubAccessibilityPermission())
        let sourceContext = ClipboardSourceContext(
            timestamp: Date(),
            capture: .eventTap,
            bundleIdentifier: "com.openai.chat",
            appName: "ChatGPT",
            processIdentifier: nil)

        pasteboard.setString(
            """
            echo old \\
            ls
            """,
            forType: .string)
        #expect(monitor.trimClipboardIfNeeded(force: false) == true)

        pasteboard.setString(
            """
            echo new \\
            pwd
            """,
            forType: .string)
        #expect(monitor.trimClipboardIfNeeded(force: false, sourceContext: sourceContext) == false)

        #expect(monitor.pasteTrimmed())
        #expect(pasteTriggered)
        #expect(pasteboard.string(forType: .string) == "echo new pwd")
    }

    @Test
    func `auto trim skips excluded browser site`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.autoTrimExcludedSites = "grok.com"
        defer { settings.autoTrimExcludedSites = "" }
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission(),
            browserLocationProvider: StubBrowserLocationProvider(host: "chat.grok.com"))
        let sourceContext = ClipboardSourceContext(
            timestamp: Date(),
            capture: .eventTap,
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            processIdentifier: nil)

        pasteboard.setString(
            """
            echo hi \\
            ls -la
            """,
            forType: .string)

        let didTrim = monitor.trimClipboardIfNeeded(force: false, sourceContext: sourceContext)
        #expect(didTrim == false)
        #expect(pasteboard.string(forType: .string)?.contains(where: \.isNewline) == true)
        #expect(monitor.lastSummary.contains("chat.grok.com"))
    }

    @Test
    func `site exclusions fail closed when browser location is unavailable`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.autoTrimExcludedSites = "grok.com"
        defer { settings.autoTrimExcludedSites = "" }
        let pasteboard = makeTestPasteboard()
        let browserLocationProvider = StubBrowserLocationProvider(host: nil)
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission(),
            browserLocationProvider: browserLocationProvider)
        let sourceContext = ClipboardSourceContext(
            timestamp: Date(),
            capture: .eventTap,
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            processIdentifier: nil)

        pasteboard.setString(
            """
            echo hi \\
            ls -la
            """,
            forType: .string)

        #expect(monitor.trimClipboardIfNeeded(force: false, sourceContext: sourceContext) == false)
        #expect(browserLocationProvider.callCount == 1)
        #expect(pasteboard.string(forType: .string)?.contains(where: \.isNewline) == true)
        #expect(monitor.lastSummary.contains("Google Chrome"))
    }

    @Test
    func `site exclusions do not affect unsupported apps`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.autoTrimExcludedSites = "grok.com"
        defer { settings.autoTrimExcludedSites = "" }
        let pasteboard = makeTestPasteboard()
        let browserLocationProvider = StubBrowserLocationProvider(host: nil)
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission(),
            browserLocationProvider: browserLocationProvider)
        let sourceContext = ClipboardSourceContext(
            timestamp: Date(),
            capture: .eventTap,
            bundleIdentifier: "com.apple.TextEdit",
            appName: "TextEdit",
            processIdentifier: nil)

        pasteboard.setString(
            """
            echo hi \\
            ls -la
            """,
            forType: .string)

        #expect(monitor.trimClipboardIfNeeded(force: false, sourceContext: sourceContext))
        #expect(browserLocationProvider.callCount == 0)
        #expect(pasteboard.string(forType: .string)?.contains(where: \.isNewline) == false)
    }

    @Test
    func `disabling auto trim stops further automatic trims`() {
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
    func `auto reflow joins hard wrapped prose and removes leading blank lines`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.generalAggressiveness = .none
        settings.autoReflowTextEnabled = true
        settings.trimLeadingBlankLinesOnReflow = true
        defer { settings.autoReflowTextEnabled = false }
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission())

        let input = [
            "",
            "The operative danger is the gradient between the source's coherence and the",
            "receiver's capacity. A prepared vessel metabolizes contact as gnosis.",
            "",
            "The second paragraph remains distinct.",
        ].joined(separator: "\n")
        let expected = [
            "The operative danger is the gradient between the source's coherence and the receiver's capacity. "
                + "A prepared vessel metabolizes contact as gnosis.",
            "",
            "The second paragraph remains distinct.",
        ].joined(separator: "\n")
        pasteboard.setString(input, forType: .string)

        #expect(monitor.trimClipboardIfNeeded(force: false))
        #expect(pasteboard.string(forType: .string) == expected)
    }

    @Test
    func `hard wrapped prose is unchanged when auto reflow is disabled`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.generalAggressiveness = .none
        settings.autoReflowTextEnabled = false
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            accessibilityPermission: StubAccessibilityPermission())

        let input = """
        The operative danger is the gradient between the source's coherence and the
        receiver's capacity. A prepared vessel metabolizes contact as gnosis.
        """
        pasteboard.setString(input, forType: .string)

        #expect(!monitor.trimClipboardIfNeeded(force: false))
        #expect(pasteboard.string(forType: .string) == input)
    }

    @Test
    func `auto reflow leaves structured text unchanged`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.generalAggressiveness = .none
        settings.autoReflowTextEnabled = true
        defer { settings.autoReflowTextEnabled = false }
        let description = "This configuration description is deliberately long enough to trigger prose detection"
        let inputs = [
            (
                "YAML",
                "description: \(description)\nenabled: true"),
            (
                "JSON",
                """
                {
                  "description": "\(description)",
                  "enabled": true
                }
                """),
            (
                "TOML",
                "description = \"\(description)\"\nenabled = true"),
            (
                "YAML block scalar",
                """
                description: |
                  \(description)
                  while remaining valid YAML that must retain its line breaks.
                """),
        ]

        for (format, input) in inputs {
            let pasteboard = makeTestPasteboard()
            let monitor = ClipboardMonitor(
                settings: settings,
                pasteboard: pasteboard,
                accessibilityPermission: StubAccessibilityPermission())
            pasteboard.setString(input, forType: .string)

            #expect(!monitor.trimClipboardIfNeeded(force: false), "Unexpected auto-reflow for \(format)")
            #expect(pasteboard.string(forType: .string) == input, "Modified \(format)")
        }
    }

    private nonisolated static let protectedReflowInputs: [String] = [
        "For more details, consult the documentation at https://example.com/a-deliberately-long-path\nsegment",
        "-- This comment is deliberately long enough to resemble wrapped prose\n"
            + "SELECT first_name, last_name FROM users",
        "description: This configuration description is deliberately long enough to trigger reflow\nenabled: true",
        "\"\"\"\nThis is a deliberately long multiline string literal\nwith a meaningful newline.\n\"\"\"",
        "A deliberately long column heading | Another column\n--- | ---\none | two",
        "description:\n  This is a deliberately long YAML plain scalar value\n"
            + "  that spans two lines.\nenabled:\n  true",
        "name,description,enabled\nexample,A deliberately long description with many words,true\n"
            + "other,Another value,false",
        "1,\"This field is deliberately long enough to resemble wrapped prose\nand intentionally continues here\",true",
        "1, A deliberately long description with many words, true\n"
            + "2, Another deliberately long description with many words, false",
        "Alice, A deliberately long description with several words\n"
            + "Bob, Another deliberately long description with several words",
        "John Doe, This field contains enough ordinary words to exceed forty characters\n"
            + "Jane Doe, Another field contains enough ordinary words to exceed forty characters",
        "    This output line is deliberately long enough to look like a prose paragraph\n"
            + "    These words are still part of an indented code block.",
        "# Output\n    This output line is deliberately long enough to look like a prose paragraph\n"
            + "    These words are still part of an indented code block.",
        "func showMessageToUser(_ message: String) {\n"
            + "    // Keep this comment separate from the call.\n    print(message)\n}",
    ]

    @Test(arguments: ClipboardMonitorTests.protectedReflowInputs)
    func `both reflow paths preserve code and configuration`(input: String) {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.generalAggressiveness = .none
        settings.contextAwareTrimmingEnabled = false
        settings.autoReflowTextEnabled = true
        settings.showMarkdownReformatOption = true
        defer { settings.autoReflowTextEnabled = false }
        let pasteboard = makeTestPasteboard()
        var pasted = false
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            pasteAction: { pasted = true },
            accessibilityPermission: StubAccessibilityPermission())
        pasteboard.setString(input, forType: .string)

        #expect(!monitor.trimClipboardIfNeeded(force: false))
        #expect(pasteboard.string(forType: .string) == input)
        #expect(monitor.markdownReformatPreviewSource() == nil)
        #expect(!monitor.pasteReformattedMarkdown())
        #expect(!pasted)
        #expect(pasteboard.string(forType: .string) == input)
    }

    @Test(arguments: [GeneralAggressiveness.none, .low, .normal, .high])
    func `automatic reflow preserves fenced examples before command cleanup`(aggressiveness: GeneralAggressiveness) {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.generalAggressiveness = aggressiveness
        settings.contextAwareTrimmingEnabled = false
        settings.autoReflowTextEnabled = true
        defer { settings.autoReflowTextEnabled = false }
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)
        let prose = "This paragraph is deliberately long enough to be recognized as wrapped prose"
        let example = "```yaml\nscript: |\n  $ echo one\n  │ literal gutter\nenabled: true\n```"
        let input = "\(prose)\nand this is its continuation.\n\n\(example)"
        pasteboard.setString(input, forType: .string)
        #expect(monitor.trimClipboardIfNeeded(force: false))
        #expect(pasteboard.string(forType: .string) == "\(prose) and this is its continuation.\n\n\(example)")
    }

    @Test
    func `automatic reflow respects disabled watcher and app exclusions`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = false
        settings.autoReflowTextEnabled = true
        settings.autoTrimExcludedApps = "com.example.reflow-test"
        defer {
            settings.autoReflowTextEnabled = false
            settings.autoTrimExcludedApps = ""
        }
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)
        let input = "This paragraph is deliberately long enough to be recognized as wrapped prose\nand continues here."
        pasteboard.setString(input, forType: .string)
        #expect(!monitor.trimClipboardIfNeeded(force: false))
        settings.autoTrimEnabled = true
        let context = ClipboardSourceContext(
            timestamp: Date(),
            capture: .eventTap,
            bundleIdentifier: "com.example.reflow-test",
            appName: "Reflow Test",
            processIdentifier: nil)
        #expect(!monitor.trimClipboardIfNeeded(force: false, sourceContext: context))
        #expect(pasteboard.string(forType: .string) == input)
    }

    @Test
    func `automatic reflow leaves command cleanup in charge of shell continuations`() {
        let settings = AppSettings()
        settings.autoTrimEnabled = true
        settings.generalAggressiveness = .normal
        settings.autoReflowTextEnabled = true
        defer { settings.autoReflowTextEnabled = false }
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(settings: settings, pasteboard: pasteboard)
        pasteboard.setString("curl https://example.com/a-deliberately-long-path \\\n  --fail", forType: .string)
        #expect(monitor.trimClipboardIfNeeded(force: false))
        #expect(pasteboard.string(forType: .string) == "curl https://example.com/a-deliberately-long-path --fail")
    }

    @Test(arguments: [false, true])
    func `repairs wrapped URL even when aggressiveness is low`(autoReflow: Bool) {
        let settings = AppSettings()
        settings.autoReflowTextEnabled = autoReflow
        defer { settings.autoReflowTextEnabled = false }
        settings.generalAggressiveness = .low
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
    func `leaves multiple separate urls untouched`() {
        let settings = AppSettings()
        settings.generalAggressiveness = .low
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
    func `paste trimmed keeps original for later`() {
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
    func `manual reflow preserves leading blank lines when removal is disabled`() {
        let settings = AppSettings()
        settings.showMarkdownReformatOption = true
        settings.trimLeadingBlankLinesOnReflow = false
        var pastedText: String?
        let pasteboard = makeTestPasteboard()
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            pasteRestoreDelay: .seconds(60),
            pasteAction: { pastedText = pasteboard.string(forType: .string) },
            accessibilityPermission: StubAccessibilityPermission())
        let input = [
            "",
            "- First item is deliberately wrapped across a long line that should be joined",
            "  with its continuation while retaining the leading blank line.",
            "- Second item remains separate.",
        ].joined(separator: "\n")
        let expected = [
            "",
            "- First item is deliberately wrapped across a long line that should be joined "
                + "with its continuation while retaining the leading blank line.",
            "- Second item remains separate.",
        ].joined(separator: "\n")
        pasteboard.setString(input, forType: .string)

        #expect(monitor.pasteReformattedMarkdown())
        #expect(pastedText == expected)
    }

    @Test
    func `paste fails gracefully when accessibility missing`() {
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
    func `URL query param strip is hidden and inert when setting is disabled`() {
        let settings = AppSettings()
        settings.showURLQueryParamStripOption = false
        defer { settings.showURLQueryParamStripOption = true }
        var pasteTriggered = false
        let pasteboard = makeTestPasteboard()
        let original = "https://example.com/article?utm_source=newsletter"
        pasteboard.setString(original, forType: .string)
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: pasteboard,
            pasteRestoreDelay: .milliseconds(0),
            pasteAction: { pasteTriggered = true },
            accessibilityPermission: StubAccessibilityPermission())

        #expect(monitor.urlQueryParamStripPreviewSource() == nil)
        #expect(monitor.pasteStrippingURLQueryParams() == false)
        #expect(pasteTriggered == false)
        #expect(pasteboard.string(forType: .string) == original)
        #expect(monitor.lastSummary == "URL strip option disabled.")
    }

    @Test
    func `paste original uses cached pre trim copy`() {
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
    func `struck marks removed decorative pipe`() {
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
    func `struck does not strike surviving pipe`() {
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
    func `struck shows whitespace removal`() {
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
    func `struck handles tabs and newlines`() {
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
