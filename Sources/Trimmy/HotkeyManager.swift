import AppKit
import KeyboardShortcuts

@MainActor
extension KeyboardShortcuts.Name {
    static let pasteTrimmed = Self("trimClipboard") // preserve existing user-defaults key
    static let pasteOriginal = Self("pasteOriginal")
    static let toggleAutoTrim = Self("toggleAutoTrim")
}

@MainActor
final class HotkeyManager: ObservableObject {
    private let settings: AppSettings
    private let monitor: ClipboardMonitor
    private var handlerRegistered = false

    init(settings: AppSettings, monitor: ClipboardMonitor) {
        self.settings = settings
        self.monitor = monitor
        self.settings.pasteTrimmedHotkeyEnabledChanged = { [weak self] _ in
            self?.refreshRegistration()
        }
        self.settings.pasteOriginalHotkeyEnabledChanged = { [weak self] _ in
            self?.refreshRegistration()
        }
        self.settings.autoTrimHotkeyEnabledChanged = { [weak self] _ in
            self?.refreshRegistration()
        }
        self.ensureDefaultShortcut()
        self.registerHandlerIfNeeded()
        self.refreshRegistration()
    }

    func refreshRegistration() {
        self.registerHandlerIfNeeded()
        if self.settings.pasteTrimmedHotkeyEnabled {
            KeyboardShortcuts.enable(.pasteTrimmed)
        } else {
            KeyboardShortcuts.disable(.pasteTrimmed)
        }

        if self.settings.pasteOriginalHotkeyEnabled {
            KeyboardShortcuts.enable(.pasteOriginal)
        } else {
            KeyboardShortcuts.disable(.pasteOriginal)
        }

        if self.settings.autoTrimHotkeyEnabled {
            KeyboardShortcuts.enable(.toggleAutoTrim)
        } else {
            KeyboardShortcuts.disable(.toggleAutoTrim)
        }
    }

    @discardableResult
    func pasteTrimmedNow() -> Bool {
        self.handlePasteTrimmedHotkey()
    }

    @discardableResult
    func pasteOriginalNow() -> Bool {
        self.handlePasteOriginalHotkey()
    }

    // Backwards compatibility for debugging hooks.
    @discardableResult
    func trimClipboardNow() -> Bool {
        self.pasteTrimmedNow()
    }

    private func registerHandlerIfNeeded() {
        guard !self.handlerRegistered else { return }
        KeyboardShortcuts.onKeyUp(for: .pasteTrimmed) { [weak self] in
            self?.handlePasteTrimmedHotkey()
        }
        KeyboardShortcuts.onKeyUp(for: .pasteOriginal) { [weak self] in
            self?.handlePasteOriginalHotkey()
        }
        KeyboardShortcuts.onKeyUp(for: .toggleAutoTrim) { [weak self] in
            self?.toggleAutoTrim()
        }
        self.handlerRegistered = true
    }

    private func ensureDefaultShortcut() {
        if KeyboardShortcuts.getShortcut(for: .pasteTrimmed) == nil {
            KeyboardShortcuts.setShortcut(
                .init(.t, modifiers: [.command, .option]),
                for: .pasteTrimmed)
        }
        // No default for auto-trim toggle; user can opt in via Settings.
    }

    @discardableResult
    private func handlePasteTrimmedHotkey() -> Bool {
        self.monitor.pasteTrimmed()
    }

    @discardableResult
    private func handlePasteOriginalHotkey() -> Bool {
        self.monitor.pasteOriginal()
    }

    private func toggleAutoTrim() {
        self.settings.autoTrimEnabled.toggle()
    }
}
