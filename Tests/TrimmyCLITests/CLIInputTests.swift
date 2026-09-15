import Foundation
import Testing
@testable import TrimmyCLI

struct CLIInputTests {
    private enum ReadFailure: Error, Equatable {
        case unavailable
    }

    @Test
    func `stdin read failures propagate`() {
        #expect(throws: ReadFailure.unavailable) {
            try TrimmyCLI.readInput(path: "-", isTTY: false) { throw ReadFailure.unavailable }
        }
    }

    @Test
    func `invalid UTF8 stdin is a decoding error`() {
        #expect(throws: CocoaError.self) {
            try TrimmyCLI.readInput(path: "-", isTTY: false) { Data([0xFF]) }
        }
    }

    @Test
    func `empty stdin remains no input`() throws {
        #expect(try TrimmyCLI.readInput(path: "-", isTTY: false) { Data() } == nil)
    }
}
