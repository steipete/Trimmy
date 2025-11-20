import AppKit
import KeyboardShortcuts

@MainActor
extension KeyboardShortcuts.Name {
    static let trimClipboard = Self("trimClipboard")
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
        self.settings.trimHotkeyEnabledChanged = { [weak self] _ in
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
        if self.settings.trimHotkeyEnabled {
            KeyboardShortcuts.enable(.trimClipboard)
        } else {
            KeyboardShortcuts.disable(.trimClipboard)
        }

        if self.settings.autoTrimHotkeyEnabled {
            KeyboardShortcuts.enable(.toggleAutoTrim)
        } else {
            KeyboardShortcuts.disable(.toggleAutoTrim)
        }
    }

    @discardableResult
    func trimClipboardNow() -> Bool {
        self.handleTrimClipboardHotkey()
    }

    private func registerHandlerIfNeeded() {
        guard !self.handlerRegistered else { return }
        KeyboardShortcuts.onKeyUp(for: .trimClipboard) { [weak self] in
            self?.handleTrimClipboardHotkey()
        }
        KeyboardShortcuts.onKeyUp(for: .toggleAutoTrim) { [weak self] in
            self?.toggleAutoTrim()
        }
        self.handlerRegistered = true
    }

    private func ensureDefaultShortcut() {
        if KeyboardShortcuts.getShortcut(for: .trimClipboard) == nil {
            KeyboardShortcuts.setShortcut(
                .init(.t, modifiers: [.command, .option]),
                for: .trimClipboard)
        }
        // No default for auto-trim toggle; user can opt in via Settings.
    }

    @discardableResult
    private func handleTrimClipboardHotkey() -> Bool {
        NSApp.activate(ignoringOtherApps: true)
        let didTrim = self.monitor.trimClipboardIfNeeded(force: true)
        if !didTrim {
            self.monitor.lastSummary = "Clipboard not trimmed (nothing command-like detected)."
        }
        return didTrim
    }

    private func toggleAutoTrim() {
        self.settings.autoTrimEnabled.toggle()
        NSApp.activate(ignoringOtherApps: true)
    }
}
