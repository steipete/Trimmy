import Testing
@testable import Trimmy

struct TerminalAppIdentifiersTests {
    @Test
    func `detects cmux bundle identifier`() {
        #expect(TerminalAppIdentifiers.isTerminal(bundleIdentifier: "com.cmuxterm.app", appName: nil))
    }

    @Test
    func `detects cmux app name fallback`() {
        #expect(TerminalAppIdentifiers.isTerminal(bundleIdentifier: nil, appName: "cmux"))
    }
}
