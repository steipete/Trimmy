import AppKit
import KeyboardShortcuts
import SwiftUI
import Testing
@testable import Trimmy

@MainActor
@Suite(.serialized)
struct ShortcutPersistenceTests {
    @Test
    func `cleared paste shortcuts stay cleared when the manager restarts`() {
        let trimmed = KeyboardShortcuts.getShortcut(for: .pasteTrimmed)
        let original = KeyboardShortcuts.getShortcut(for: .pasteOriginal)
        defer {
            KeyboardShortcuts.setShortcut(trimmed, for: .pasteTrimmed)
            KeyboardShortcuts.setShortcut(original, for: .pasteOriginal)
        }
        let settings = AppSettings()
        let enabled = (
            settings.pasteTrimmedHotkeyEnabled,
            settings.pasteOriginalHotkeyEnabled,
            settings.autoTrimHotkeyEnabled)
        defer {
            settings.pasteTrimmedHotkeyEnabled = enabled.0
            settings.pasteOriginalHotkeyEnabled = enabled.1
            settings.autoTrimHotkeyEnabled = enabled.2
        }
        settings.pasteTrimmedHotkeyEnabled = false
        settings.pasteOriginalHotkeyEnabled = false
        settings.autoTrimHotkeyEnabled = false
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: makeTestPasteboard(),
            pasteAction: {},
            accessibilityPermission: StubAccessibilityPermission())
        KeyboardShortcuts.setShortcut(nil, for: .pasteTrimmed)
        KeyboardShortcuts.setShortcut(nil, for: .pasteOriginal)
        let manager = HotkeyManager(settings: settings, monitor: monitor)
        #expect(KeyboardShortcuts.getShortcut(for: .pasteTrimmed) == nil)
        #expect(KeyboardShortcuts.getShortcut(for: .pasteOriginal) == nil)
        withExtendedLifetime(manager) {}
    }

    @Test
    func `function key shortcuts appear in the menu`() {
        let saved = KeyboardShortcuts.getShortcut(for: .pasteTrimmed)
        let settings = AppSettings()
        let enabled = settings.pasteTrimmedHotkeyEnabled
        defer {
            KeyboardShortcuts.setShortcut(saved, for: .pasteTrimmed)
            settings.pasteTrimmedHotkeyEnabled = enabled
        }
        KeyboardShortcuts.setShortcut(.init(.f9, modifiers: [.command, .control]), for: .pasteTrimmed)
        settings.pasteTrimmedHotkeyEnabled = true
        let monitor = ClipboardMonitor(
            settings: settings,
            pasteboard: makeTestPasteboard(),
            pasteAction: {},
            accessibilityPermission: StubAccessibilityPermission())
        let view = MenuContentView(
            monitor: monitor,
            settings: settings,
            permissions: AccessibilityPermissionManager(),
            updater: DisabledUpdaterController())
        #expect(view.pasteTrimmedKeyboardShortcut?.key == KeyEquivalent("\u{F70C}"))
        #expect(view.pasteTrimmedKeyboardShortcut?.modifiers == [.command, .control])
        settings.pasteTrimmedHotkeyEnabled = false
        #expect(view.pasteTrimmedKeyboardShortcut == nil)
    }
}
