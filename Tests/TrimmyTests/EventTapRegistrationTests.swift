import AppKit
import Testing
@testable import Trimmy

struct EventTapRegistrationTests {
    @Test
    func `registration invalidates its port and run loop source on release`() throws {
        let createdPort = CFMachPortCreate(nil, { _, _, _, _ in }, nil, nil)
        let port = try #require(createdPort)
        let source = try #require(CFMachPortCreateRunLoopSource(nil, port, 0))
        var registration: CopyEventTap.Registration? = CopyEventTap.Registration(tap: port, source: source)
        #expect(registration != nil)
        #expect(CFMachPortIsValid(port))
        #expect(CFRunLoopSourceIsValid(source))
        registration = nil
        #expect(!CFMachPortIsValid(port))
        #expect(!CFRunLoopSourceIsValid(source))
    }
}
