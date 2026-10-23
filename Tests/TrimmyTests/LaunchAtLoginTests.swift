import Foundation
import Testing
@testable import Trimmy

@MainActor
@Suite(.serialized)
struct LaunchAtLoginTests {
    @Test(arguments: [false, true])
    func `failed changes restore the saved preference and successful retries clear the error`(saved: Bool) {
        let previousValue = UserDefaults.standard.object(forKey: "launchAtLogin")
        defer { Self.restore(previousValue) }
        UserDefaults.standard.set(saved, forKey: "launchAtLogin")
        var attempts: [Bool] = []
        var shouldFail = false
        let settings = AppSettings { enabled in
            attempts.append(enabled)
            if shouldFail {
                throw CocoaError(.fileWriteUnknown)
            }
        }

        shouldFail = true
        settings.launchAtLogin = !saved
        #expect(settings.launchAtLogin == saved)
        #expect(UserDefaults.standard.bool(forKey: "launchAtLogin") == saved)
        #expect(attempts == [saved, !saved])
        #expect(settings.launchAtLoginError?.contains("Login Items") == true)

        shouldFail = false
        settings.launchAtLogin = !saved
        #expect(settings.launchAtLogin == !saved)
        #expect(UserDefaults.standard.bool(forKey: "launchAtLogin") == !saved)
        #expect(settings.launchAtLoginError == nil)
        #expect(attempts == [saved, !saved, !saved])
    }

    @Test(arguments: [false, true])
    func `startup failures preserve existing choices for the next launch`(saved: Bool) {
        let previousValue = UserDefaults.standard.object(forKey: "launchAtLogin")
        defer { Self.restore(previousValue) }
        UserDefaults.standard.set(saved, forKey: "launchAtLogin")
        var attempts: [Bool] = []
        let settings = AppSettings { enabled in
            attempts.append(enabled)
            throw CocoaError(.fileWriteUnknown)
        }
        #expect(settings.launchAtLogin == saved)
        #expect(UserDefaults.standard.bool(forKey: "launchAtLogin") == saved)
        #expect(settings.launchAtLoginError?.contains("Start at Login") == true)
        #expect(settings.launchAtLoginError?.contains("Login Items") == true)

        let relaunched = AppSettings { enabled in attempts.append(enabled) }
        #expect(relaunched.launchAtLogin == saved)
        #expect(relaunched.launchAtLoginError == nil)
        #expect(attempts == [saved, saved])
    }

    private static func restore(_ previousValue: Any?) {
        if let previousValue {
            UserDefaults.standard.set(previousValue, forKey: "launchAtLogin")
        } else {
            UserDefaults.standard.removeObject(forKey: "launchAtLogin")
        }
    }
}
