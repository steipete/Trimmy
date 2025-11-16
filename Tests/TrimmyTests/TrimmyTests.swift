import XCTest
@testable import Trimmy

final class TrimmyTests: XCTestCase {
    func testRejoinsNewlineInsideToken() {
        let settings = AppSettings()
        settings.aggressiveness = .high
        settings.preserveBlankLines = false
        settings.autoTrimEnabled = true
        let detector = CommandDetector(settings: settings)

        let input = """
        cd /Users/steipete/Projects/Peekaboo && N
        ODE_PATH=../poltergeist/node_modules ./runner pnpm --dir ../poltergeist exec tsx ../poltergeist/src/polter.ts
        """

        let flattened = detector.transformIfCommand(input)
        XCTAssertEqual(
            flattened,
            "cd /Users/steipete/Projects/Peekaboo && NODE_PATH=../poltergeist/node_modules ./runner pnpm --dir ../poltergeist exec tsx ../poltergeist/src/polter.ts")
    }

    func testLeavesSingleLineAlone() {
        let settings = AppSettings()
        settings.aggressiveness = .high
        let detector = CommandDetector(settings: settings)

        let input = "echo hello"
        XCTAssertNil(detector.transformIfCommand(input))
    }
}
