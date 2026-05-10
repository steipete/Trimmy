import AppKit
import Carbon.HIToolbox
import Foundation

/// Captures Cmd-C key presses via a session event tap.
///
/// Requires Accessibility / Input Monitoring permission depending on macOS settings.
final class CopyEventTap {
    struct CopyKeypressContext {
        let timestamp: Date
        let pasteboardChangeCount: Int
        let bundleIdentifier: String?
        let appName: String?
        let processIdentifier: pid_t?
    }

    private let pasteboard: NSPasteboard
    private let onCopy: @Sendable (CopyKeypressContext) -> Void
    private var tap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    @MainActor
    init(
        pasteboard: NSPasteboard = .general,
        onCopy: @escaping @Sendable (CopyKeypressContext) -> Void)
    {
        self.pasteboard = pasteboard
        self.onCopy = onCopy
    }

    var isRunning: Bool {
        self.tap != nil
    }

    @MainActor
    func start() -> Bool {
        guard self.tap == nil else { return true }

        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let refcon = Unmanaged.passUnretained(self).toOpaque()
        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: Self.eventTapCallback,
            userInfo: refcon)
        else {
            return false
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        self.tap = tap
        self.runLoopSource = source
        return true
    }

    @MainActor
    func stop() {
        guard let tap = self.tap, let source = self.runLoopSource else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        self.tap = nil
        self.runLoopSource = nil
    }

    private func handleEventTap(type: CGEventType, event: CGEvent) {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = self.tap {
                Telemetry.eventTap.warning("Event tap disabled; re-enabling.")
                CGEvent.tapEnable(tap: tap, enable: true)
            }
            return
        }

        guard type == .keyDown else { return }
        guard event.flags.contains(.maskCommand) else { return }

        let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
        guard keyCode == Int64(kVK_ANSI_C) else { return }
        guard event.getIntegerValueField(.keyboardEventAutorepeat) == 0 else { return }

        CFRunLoopPerformBlock(CFRunLoopGetMain(), CFRunLoopMode.commonModes.rawValue) { [weak self] in
            guard let self else { return }
            let app = NSWorkspace.shared.frontmostApplication
            let ctx = CopyKeypressContext(
                timestamp: Date(),
                pasteboardChangeCount: self.pasteboard.changeCount,
                bundleIdentifier: app?.bundleIdentifier,
                appName: app?.localizedName,
                processIdentifier: app?.processIdentifier)
            self.onCopy(ctx)
        }
        CFRunLoopWakeUp(CFRunLoopGetMain())
    }

    private static let eventTapCallback: CGEventTapCallBack = { _, type, event, refcon in
        guard let refcon else { return Unmanaged.passUnretained(event) }
        let monitor = Unmanaged<CopyEventTap>.fromOpaque(refcon).takeUnretainedValue()
        monitor.handleEventTap(type: type, event: event)
        return Unmanaged.passUnretained(event)
    }
}
