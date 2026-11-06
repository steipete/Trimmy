import AppKit
import Foundation

enum ClipboardSourceCapture: String { case eventTap, snapshot }

struct FrontmostAppSnapshot {
    let bundleIdentifier: String?
    let appName: String?
    let processIdentifier: pid_t?
}

struct ClipboardSourceContext {
    let timestamp: Date
    let capture: ClipboardSourceCapture
    let bundleIdentifier: String?
    let appName: String?
    let processIdentifier: pid_t?

    var isTerminal: Bool {
        TerminalAppIdentifiers.isTerminal(bundleIdentifier: self.bundleIdentifier, appName: self.appName)
    }

    var debugLabel: String {
        let name = self.appName ?? "nil"
        let bundle = self.bundleIdentifier ?? "nil"
        return "\(self.capture.rawValue) \(name) (\(bundle))"
    }
}

@MainActor
final class ClipboardSourceTracker {
    private let settings: AppSettings
    private let pasteboard: NSPasteboard
    private let accessibilityPermission: AccessibilityPermissionChecking
    private var copyEventTap: CopyEventTap?
    private var lastCopyKeypress: CopyEventTap.CopyKeypressContext?
    private var pending: [Int: ClipboardSourceContext] = [:]
    var frontmostApp: @MainActor () -> FrontmostAppSnapshot

    init(settings: AppSettings, pasteboard: NSPasteboard, accessibilityPermission: AccessibilityPermissionChecking) {
        self.settings = settings
        self.pasteboard = pasteboard
        self.accessibilityPermission = accessibilityPermission
        self.frontmostApp = {
            let app = NSWorkspace.shared.frontmostApplication
            return FrontmostAppSnapshot(
                bundleIdentifier: app?.bundleIdentifier,
                appName: app?.localizedName,
                processIdentifier: app?.processIdentifier)
        }
    }

    func updateIfNeeded() {
        guard self.settings.contextAwareTrimmingEnabled else {
            if self.copyEventTap?.isRunning == true {
                Telemetry.eventTap.info("Stopping Cmd-C event tap (setting off).")
            }
            self.copyEventTap?.stop()
            return
        }

        guard self.accessibilityPermission.isTrusted else {
            if self.copyEventTap?.isRunning == true {
                Telemetry.eventTap.info("Stopping Cmd-C event tap (permission missing).")
            }
            self.copyEventTap?.stop()
            return
        }

        if self.copyEventTap == nil {
            self.copyEventTap = CopyEventTap(pasteboard: self.pasteboard) { [weak self] ctx in
                Task { @MainActor in
                    self?.recordCopyKeypress(ctx)
                }
            }
        }

        guard self.copyEventTap?.isRunning != true else { return }
        if self.copyEventTap?.start() == true {
            Telemetry.eventTap.info("Started Cmd-C event tap.")
        } else {
            Telemetry.eventTap.error("Failed starting Cmd-C event tap (missing permission?).")
        }
    }

    func stop() {
        self.copyEventTap?.stop()
    }

    func recordObservedChangeCount(_ observed: Int) -> ClipboardSourceContext {
        let ctx = self.captureSourceContext(forObservedChangeCount: observed)
        self.pending[observed] = ctx
        return ctx
    }

    func discardObservedChangeCount(_ observed: Int) {
        self.pending.removeValue(forKey: observed)
    }

    func consumeContext(forObservedChangeCount observed: Int) -> ClipboardSourceContext? {
        self.pending.removeValue(forKey: observed)
    }

    func recordCopyKeypress(_ ctx: CopyEventTap.CopyKeypressContext) {
        self.lastCopyKeypress = ctx
        Telemetry.eventTap.debug(
            """
            Cmd-C captured app=\(ctx.appName ?? "nil", privacy: .public) \
            bundle=\(ctx.bundleIdentifier ?? "nil", privacy: .public) \
            pb=\(ctx.pasteboardChangeCount, privacy: .public).
            """)
    }

    private func captureSourceContext(forObservedChangeCount observed: Int) -> ClipboardSourceContext {
        let now = Date()
        let front = self.frontmostApp()
        if let keypress = self.lastCopyKeypress,
           observed > keypress.pasteboardChangeCount,
           now.timeIntervalSince(keypress.timestamp) < 2.0
        {
            self.lastCopyKeypress = nil
            if self.keypressMatches(keypress, front: front) {
                return ClipboardSourceContext(
                    timestamp: now,
                    capture: .eventTap,
                    bundleIdentifier: keypress.bundleIdentifier,
                    appName: keypress.appName,
                    processIdentifier: keypress.processIdentifier)
            }
            return self.snapshotContext(at: now, front: front)
        }

        return self.snapshotContext(at: now, front: front)
    }

    private func snapshotContext(at now: Date, front: FrontmostAppSnapshot) -> ClipboardSourceContext {
        ClipboardSourceContext(
            timestamp: now,
            capture: .snapshot,
            bundleIdentifier: front.bundleIdentifier,
            appName: front.appName,
            processIdentifier: front.processIdentifier)
    }

    private func keypressMatches(
        _ keypress: CopyEventTap.CopyKeypressContext,
        front: FrontmostAppSnapshot) -> Bool
    {
        if let keyPID = keypress.processIdentifier, let frontPID = front.processIdentifier, keyPID > 0, frontPID > 0 {
            return keyPID == frontPID
        }
        if let keyBundle = keypress.bundleIdentifier, let frontBundle = front.bundleIdentifier,
           !keyBundle.isEmpty, !frontBundle.isEmpty
        {
            return keyBundle == frontBundle
        }
        return true
    }
}
