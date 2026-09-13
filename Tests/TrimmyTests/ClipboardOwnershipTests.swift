import AppKit
import Testing
@testable import Trimmy

@MainActor
@Suite(.serialized)
struct ClipboardOwnershipTests {
    private func settings() -> AppSettings {
        let settings = AppSettings()
        settings.autoTrimEnabled = false
        settings.generalAggressiveness = .normal
        settings.autoReflowTextEnabled = false
        settings.contextAwareTrimmingEnabled = false
        return settings
    }

    private func copy(_ text: String, to board: NSPasteboard) {
        board.clearContents()
        board.setString(text, forType: .string)
    }

    @Test
    func `manual paste reads a new copy while auto trim is disabled`() {
        let board = makeTestPasteboard()
        var pasted: String?
        var restore: (@MainActor @Sendable () -> Void)?
        let monitor = ClipboardMonitor(
            settings: self.settings(),
            pasteboard: board,
            pasteAction: { pasted = board.string(forType: .string) },
            accessibilityPermission: StubAccessibilityPermission(),
            restoreScheduler: { restore = $0 })
        self.copy("old copy", to: board)
        monitor.trimClipboardIfNeeded(force: true)
        self.copy("new copy", to: board)

        #expect(monitor.pasteOriginal())
        #expect(pasted == "new copy")
        restore?()
        self.copy("newest copy", to: board)
        #expect(monitor.pasteTrimmed())
        #expect(pasted == "newest copy")
        restore?()
    }

    @Test
    func `ignoring an owned write preserves the original copy`() {
        let board = makeTestPasteboard()
        let settings = self.settings()
        settings.autoTrimEnabled = true
        var pasted: String?
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: board,
            pasteAction: { pasted = board.string(forType: .string) },
            accessibilityPermission: StubAccessibilityPermission(),
            restoreScheduler: { $0() })
        let original = "echo first\n  second"
        self.copy(original, to: board)
        #expect(monitor.trimClipboardIfNeeded(force: true))
        #expect(!monitor.trimClipboardIfNeeded())
        #expect(monitor.pasteOriginal())
        #expect(pasted == original)
    }

    @Test
    func `nontext copy invalidates the cached original`() {
        let board = makeTestPasteboard()
        var didPaste = false
        let monitor = ClipboardMonitor(
            settings: self.settings(),
            pasteboard: board,
            pasteAction: { didPaste = true },
            accessibilityPermission: StubAccessibilityPermission(),
            restoreScheduler: { _ in })
        self.copy("old copy", to: board)
        monitor.trimClipboardIfNeeded(force: true)
        board.clearContents()
        board.setData(Data([1, 2, 3]), forType: .init("com.example.nontext"))

        #expect(!monitor.pasteOriginal())
        #expect(!monitor.pasteTrimmed())
        #expect(!didPaste)
    }

    @Test
    func `delayed restore never replaces a newer user copy`() {
        let board = makeTestPasteboard()
        var restore: (@MainActor @Sendable () -> Void)?
        let monitor = ClipboardMonitor(
            settings: self.settings(),
            pasteboard: board,
            pasteAction: {},
            accessibilityPermission: StubAccessibilityPermission(),
            restoreScheduler: { restore = $0 })
        self.copy("before paste", to: board)
        #expect(monitor.pasteTrimmed())
        self.copy("new user copy", to: board)
        let userChangeCount = board.changeCount

        restore?()
        #expect(board.string(forType: .string) == "new user copy")
        #expect(board.changeCount == userChangeCount)
    }

    @Test
    func `repeated pastes restore the original items and representations once`() {
        let board = makeTestPasteboard()
        let customType = NSPasteboard.PasteboardType("com.example.fixture")
        let first = NSPasteboardItem()
        first.setString("first item", forType: .string)
        first.setData(Data([1, 2, 3]), forType: customType)
        let second = NSPasteboardItem()
        second.setString("second item", forType: .string)
        board.writeObjects([first, second])
        var restores: [@MainActor @Sendable () -> Void] = []
        let monitor = ClipboardMonitor(
            settings: self.settings(),
            pasteboard: board,
            pasteAction: {},
            accessibilityPermission: StubAccessibilityPermission(),
            restoreScheduler: { restores.append($0) })

        #expect(monitor.pasteTrimmed())
        #expect(monitor.pasteOriginal())
        let temporaryChangeCount = board.changeCount
        #expect(restores.count == 2)
        restores[0]()
        #expect(board.changeCount == temporaryChangeCount)
        #expect(board.types?.contains(.init("com.steipete.trimmy")) == true)
        restores[1]()

        #expect(board.pasteboardItems?.count == 2)
        #expect(board.pasteboardItems?.first?.string(forType: .string) == "first item")
        #expect(board.pasteboardItems?.first?.data(forType: customType) == Data([1, 2, 3]))
        #expect(board.pasteboardItems?.last?.string(forType: .string) == "second item")
        #expect(board.types?.contains(.init("com.steipete.trimmy")) == false)
    }
}
