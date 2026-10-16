import Foundation
import Testing
@testable import Trimmy

struct LaunchAtLoginTests {
    @Test
    func `a failed login item change restores the previous toggle`() {
        let change = LaunchAtLoginChange.applying(true, previous: false) { _ in
            throw CocoaError(.fileWriteUnknown)
        }
        #expect(change.enabled == false)
        #expect(change.error?.contains("Start at Login") == true)
        #expect(change.error?.contains("Login Items") == true)
    }

    @Test
    func `a successful login item change keeps the requested toggle`() {
        let change = LaunchAtLoginChange.applying(true, previous: false) { _ in }
        #expect(change.enabled == true)
        #expect(change.error == nil)
    }

    @MainActor
    @Test
    func `settings restore the toggle when login item registration fails`() {
        let previousHook = LaunchAtLoginManager.setEnabledBody
        let previousValue = UserDefaults.standard.object(forKey: "launchAtLogin")
        defer {
            LaunchAtLoginManager.setEnabledBody = previousHook
            if let previousValue {
                UserDefaults.standard.set(previousValue, forKey: "launchAtLogin")
            } else {
                UserDefaults.standard.removeObject(forKey: "launchAtLogin")
            }
        }

        UserDefaults.standard.set(false, forKey: "launchAtLogin")
        let fail = LockedFlag()
        LaunchAtLoginManager.setEnabledBody = { enabled in
            if fail.value, enabled {
                throw CocoaError(.fileWriteUnknown)
            }
        }
        let settings = AppSettings()
        fail.value = true
        settings.launchAtLogin = true
        #expect(settings.launchAtLogin == false)
        #expect(settings.launchAtLoginError?.contains("Login Items") == true)
    }

    @MainActor
    @Test
    func `a launch failure does not rewrite the saved login preference`() {
        let previousHook = LaunchAtLoginManager.setEnabledBody
        let previousValue = UserDefaults.standard.object(forKey: "launchAtLogin")
        defer {
            LaunchAtLoginManager.setEnabledBody = previousHook
            if let previousValue {
                UserDefaults.standard.set(previousValue, forKey: "launchAtLogin")
            } else {
                UserDefaults.standard.removeObject(forKey: "launchAtLogin")
            }
        }

        UserDefaults.standard.set(true, forKey: "launchAtLogin")
        LaunchAtLoginManager.setEnabledBody = { _ in
            throw CocoaError(.fileWriteUnknown)
        }
        let settings = AppSettings()
        #expect(settings.launchAtLogin == true)
        #expect(UserDefaults.standard.bool(forKey: "launchAtLogin"))
        #expect(settings.launchAtLoginError?.contains("Start at Login") == true)
    }
}

private final class LockedFlag: @unchecked Sendable {
    var value = false
}
