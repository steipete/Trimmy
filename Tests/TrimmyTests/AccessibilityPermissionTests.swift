import Testing
@testable import Trimmy

@MainActor
struct AccessibilityPermissionTests {
    @Test
    func `polling releases the permission manager while sleeping`() async {
        var manager: AccessibilityPermissionManager? = AccessibilityPermissionManager(pollInterval: 600)
        weak var reference = manager
        await Task.yield()
        manager = nil
        #expect(reference == nil)
    }

    @Test
    func `development builds disable the updater`() {
        let updater = makeUpdaterController()
        #expect(!updater.isAvailable)
        #expect(updater.unavailableReason == "Updates are disabled in development builds.")
    }
}
