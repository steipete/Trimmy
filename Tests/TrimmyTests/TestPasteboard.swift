import AppKit
@testable import Trimmy

func makeTestPasteboard() -> NSPasteboard {
    let name = NSPasteboard.Name("dev.steipete.trimmy-tests-\(UUID().uuidString)")
    let board = NSPasteboard(name: name)
    board.clearContents()
    return board
}

@MainActor
final class StubAccessibilityPermission: AccessibilityPermissionChecking {
    var isTrusted: Bool

    init(isTrusted: Bool = true) {
        self.isTrusted = isTrusted
    }
}
