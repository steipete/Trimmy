import AppKit
import Testing
@testable import Trimmy

@MainActor
@Suite(.serialized)
struct ClipboardSourceTrackerTests {
    private func makeTracker(front: FrontmostAppSnapshot) -> ClipboardSourceTracker {
        let tracker = ClipboardSourceTracker(
            settings: AppSettings(),
            pasteboard: makeTestPasteboard(),
            accessibilityPermission: StubAccessibilityPermission())
        tracker.frontmostApp = { front }
        return tracker
    }

    private func keypress(
        appName: String,
        bundleIdentifier: String,
        processIdentifier: pid_t,
        changeCount: Int,
        timestamp: Date = Date()) -> CopyEventTap.CopyKeypressContext
    {
        CopyEventTap.CopyKeypressContext(
            timestamp: timestamp,
            pasteboardChangeCount: changeCount,
            bundleIdentifier: bundleIdentifier,
            appName: appName,
            processIdentifier: processIdentifier)
    }

    @Test
    func `a Cmd-C still claims the pasteboard change while that app is frontmost`() {
        let terminal = FrontmostAppSnapshot(
            bundleIdentifier: "com.apple.Terminal",
            appName: "Terminal",
            processIdentifier: 10)
        let tracker = self.makeTracker(front: terminal)
        tracker.recordCopyKeypress(self.keypress(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            processIdentifier: 10,
            changeCount: 5))

        let context = tracker.recordObservedChangeCount(6)

        #expect(context.capture == .eventTap)
        #expect(context.bundleIdentifier == "com.apple.Terminal")
        #expect(context.appName == "Terminal")
        #expect(context.processIdentifier == 10)
    }

    @Test
    func `a failed Cmd-C does not claim the next copy from another app`() {
        let browser = FrontmostAppSnapshot(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            processIdentifier: 20)
        let tracker = self.makeTracker(front: browser)
        tracker.recordCopyKeypress(self.keypress(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            processIdentifier: 10,
            changeCount: 5,
            timestamp: Date().addingTimeInterval(-1)))

        let context = tracker.recordObservedChangeCount(6)

        #expect(context.capture == .snapshot)
        #expect(context.bundleIdentifier == "com.google.Chrome")
        #expect(context.appName == "Google Chrome")
        #expect(context.processIdentifier == 20)
    }

    @Test
    func `a Cmd-C still claims a copy when the user switches apps before the next poll`() {
        let browser = FrontmostAppSnapshot(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            processIdentifier: 20)
        let tracker = self.makeTracker(front: browser)
        tracker.recordCopyKeypress(self.keypress(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            processIdentifier: 10,
            changeCount: 5,
            timestamp: Date().addingTimeInterval(-0.05)))

        let context = tracker.recordObservedChangeCount(6)

        #expect(context.capture == .eventTap)
        #expect(context.bundleIdentifier == "com.apple.Terminal")
        #expect(context.appName == "Terminal")
        #expect(context.processIdentifier == 10)
    }

    @Test
    func `a consumed Cmd-C is not reused for a later copy`() {
        let browser = FrontmostAppSnapshot(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            processIdentifier: 20)
        let tracker = self.makeTracker(front: browser)
        tracker.recordCopyKeypress(self.keypress(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            processIdentifier: 10,
            changeCount: 5))
        _ = tracker.recordObservedChangeCount(6)

        tracker.frontmostApp = {
            FrontmostAppSnapshot(
                bundleIdentifier: "com.apple.Notes",
                appName: "Notes",
                processIdentifier: 30)
        }
        let later = tracker.recordObservedChangeCount(7)

        #expect(later.capture == .snapshot)
        #expect(later.bundleIdentifier == "com.apple.Notes")
        #expect(later.processIdentifier == 30)
    }

    @Test
    func `a Cmd-C older than two seconds does not claim a later copy`() {
        let browser = FrontmostAppSnapshot(
            bundleIdentifier: "com.google.Chrome",
            appName: "Google Chrome",
            processIdentifier: 20)
        let tracker = self.makeTracker(front: browser)
        tracker.recordCopyKeypress(self.keypress(
            appName: "Terminal",
            bundleIdentifier: "com.apple.Terminal",
            processIdentifier: 10,
            changeCount: 5,
            timestamp: Date().addingTimeInterval(-3)))

        let context = tracker.recordObservedChangeCount(6)

        #expect(context.capture == .snapshot)
        #expect(context.bundleIdentifier == "com.google.Chrome")
    }
}
