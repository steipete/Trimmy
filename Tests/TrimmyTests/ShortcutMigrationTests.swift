import Foundation
import Testing
@testable import Trimmy

@MainActor
struct ShortcutMigrationTests {
    @Test
    func `legacy cleared shortcuts become explicit disabled entries`() throws {
        let domain = "trimmy-shortcut-migration-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set("normal", forKey: "terminalAggressiveness")
        AppSettings.migrateShortcutDefaults(defaults)
        #expect(defaults.object(forKey: "KeyboardShortcuts_trimClipboard") as? Bool == false)
        #expect(defaults.object(forKey: "KeyboardShortcuts_pasteOriginal") as? Bool == false)
    }

    @Test
    func `migration preserves existing shortcuts`() throws {
        let domain = "trimmy-shortcut-migration-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        defaults.set("saved shortcut fixture", forKey: "KeyboardShortcuts_trimClipboard")
        defaults.set(false, forKey: "KeyboardShortcuts_pasteOriginal")
        AppSettings.migrateShortcutDefaults(defaults)
        #expect(defaults.string(forKey: "KeyboardShortcuts_trimClipboard") == "saved shortcut fixture")
        #expect(defaults.object(forKey: "KeyboardShortcuts_pasteOriginal") as? Bool == false)
    }

    @Test
    func `new installations keep initial shortcuts eligible across initialization`() throws {
        let domain = "trimmy-shortcut-migration-\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: domain))
        defer { defaults.removePersistentDomain(forName: domain) }
        AppSettings.migrateShortcutDefaults(defaults)
        defaults.set("normal", forKey: "terminalAggressiveness")
        AppSettings.migrateShortcutDefaults(defaults)
        #expect(defaults.object(forKey: "KeyboardShortcuts_trimClipboard") == nil)
        #expect(defaults.object(forKey: "KeyboardShortcuts_pasteOriginal") == nil)
    }
}
