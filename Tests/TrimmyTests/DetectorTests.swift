import XCTest
@testable import Trimmy

final class DetectorTests: XCTestCase {
    private func makeDetector(level: Aggressiveness = .normal, preserveBlanks: Bool = false) -> CommandDetector {
        let settings = AppSettings()
        settings.aggressiveness = level
        settings.preserveBlankLines = preserveBlanks
        return CommandDetector(settings: settings)
    }

    func testFlattenRespectsBlankLinesWhenEnabled() {
        let detector = makeDetector(level: .high, preserveBlanks: true)
        let input = "echo one\n\n\necho two"
        let output = detector.transformIfCommand(input)
        XCTAssertEqual(output, "echo one\n\necho two")
    }

    func testFlattenRemovesBlankLinesByDefault() {
        let detector = makeDetector(level: .high, preserveBlanks: false)
        let input = "echo one\n\n\necho two"
        let output = detector.transformIfCommand(input)
        XCTAssertEqual(output, "echo one echo two")
    }

    func testRequiresScoreInLowMode() {
        let detector = makeDetector(level: .low)
        let input = "line1\nline2" // looks too generic
        let output = detector.transformIfCommand(input)
        XCTAssertNil(output)
    }

    func testCommandDetectedInLowModeWhenVeryCommandy() {
        let detector = makeDetector(level: .low)
        let input = "sudo apt-get\nupdate"
        let output = detector.transformIfCommand(input)
        XCTAssertEqual(output, "sudo apt-get update")
    }

    func testBackslashContinuationHandled() {
        let detector = makeDetector(level: .high)
        let input = "npm install \\\n  leftpad"
        let output = detector.transformIfCommand(input)
        XCTAssertEqual(output, "npm install leftpad")
    }
}
