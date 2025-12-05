import AppKit
import Carbon.HIToolbox
import Foundation
import TrimmyCore

@MainActor
final class ClipboardMonitor: ObservableObject {
    private let settings: AppSettings
    private let pasteboard: NSPasteboard
    private let trimmyMarker = NSPasteboard.PasteboardType("com.steipete.trimmy")
    private let accessibilityPermission: AccessibilityPermissionChecking
    private var timer: DispatchSourceTimer?
    private var lastSeenChangeCount: Int
    private var detector: CommandDetector { CommandDetector(settings: self.settings) }
    private let pollInterval: DispatchTimeInterval = .milliseconds(150)
    private let pollLeeway: DispatchTimeInterval = .milliseconds(50)
    private let graceDelay: DispatchTimeInterval = .milliseconds(80)
    private let pasteRestoreDelay: DispatchTimeInterval
    private let pasteIntoFrontmostApp: () -> Void
    private var ignoredChangeCounts: Set<Int> = []
    private var lastOriginalText: String?
    private var lastTrimmedText: String?

    @Published var lastSummary: String = ""
    @Published var frontmostAppName: String = "current app"
    @Published var trimPulseID: Int = 0

    init(
        settings: AppSettings,
        pasteboard: NSPasteboard = NSPasteboard.general,
        pasteRestoreDelay: DispatchTimeInterval = .milliseconds(200),
        pasteAction: (() -> Void)? = nil,
        accessibilityPermission: AccessibilityPermissionChecking = AccessibilityPermissionManager())
    {
        self.settings = settings
        self.pasteboard = pasteboard
        self.accessibilityPermission = accessibilityPermission
        self.pasteRestoreDelay = pasteRestoreDelay
        self.pasteIntoFrontmostApp = pasteAction ?? ClipboardMonitor.sendPasteCommand
        self.lastSeenChangeCount = self.pasteboard.changeCount
        self.updateFrontmostAppName(NSWorkspace.shared.frontmostApplication)
        NSWorkspace.shared.notificationCenter.addObserver(
            self,
            selector: #selector(self.handleAppActivation(_:)),
            name: NSWorkspace.didActivateApplicationNotification,
            object: nil)
    }

    deinit {
        NSWorkspace.shared.notificationCenter.removeObserver(self)
    }

    func start() {
        self.stop()
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        t.schedule(deadline: .now(), repeating: self.pollInterval, leeway: self.pollLeeway)
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        t.resume()
        self.timer = t
    }

    func stop() {
        self.timer?.cancel()
        self.timer = nil
    }

    @discardableResult
    func trimClipboardIfNeeded(force: Bool = false) -> Bool {
        let changeCount = self.pasteboard.changeCount
        self.lastSeenChangeCount = changeCount

        guard let variants = self.makeVariants(force: force, ignoreMarker: force) else {
            // For forced/manual trims, still surface the current clipboard text in “Last” even when
            // nothing was transformed, so the menu reflects what the user tried to trim.
            if force, let raw = self.readTextFromPasteboard(ignoreMarker: true) {
                self.updateSummary(with: raw)
                return true
            }
            return false
        }

        guard self.settings.autoTrimEnabled || force else { return false }

        self.writeTrimmed(variants.trimmed)
        self.lastSeenChangeCount = self.pasteboard.changeCount
        self.updateSummary(with: variants.trimmed)
        self.registerTrimEvent()
        return true
    }

    private func tick() {
        let current = self.pasteboard.changeCount
        guard current != self.lastSeenChangeCount else { return }

        if self.ignoredChangeCounts.remove(current) != nil {
            self.lastSeenChangeCount = current
            return
        }

        let observed = current
        // Grace delay lets promised pasteboard data settle before we read/transform.
        DispatchQueue.main.asyncAfter(deadline: .now() + self.graceDelay) { [weak self] in
            guard let self, observed == self.pasteboard.changeCount else { return }
            _ = self.trimClipboardIfNeeded()
            self.lastSeenChangeCount = self.pasteboard.changeCount
        }
    }

    private func readTextFromPasteboard(ignoreMarker: Bool = false) -> String? {
        if !ignoreMarker, self.pasteboard.types?.contains(self.trimmyMarker) == true { return nil }

        if let direct = self.pasteboard.string(forType: .string) {
            return self.normalizeLineEndings(direct)
        }

        guard self.settings.usePasteboardFallbacks else { return nil }

        // Fall back to scanning pasteboard items for any text-like representation.
        let preferredTypes: [NSPasteboard.PasteboardType] = [
            .init("public.utf8-plain-text"),
            .init("public.utf16-external-plain-text"),
            .init("public.text"),
            .init("public.rtf"),
        ]

        for item in self.pasteboard.pasteboardItems ?? [] {
            for type in preferredTypes {
                if let value = item.string(forType: type) {
                    return self.normalizeLineEndings(value)
                }
            }
        }
        return nil
    }

    /// Exposes the current clipboard string (nil if empty or Trimmy marker).
    func clipboardText() -> String? {
        self.readTextFromPasteboard(ignoreMarker: true)
    }

    private func writeTrimmed(_ text: String) {
        self.pasteboard.declareTypes([.string, self.trimmyMarker], owner: nil)
        self.pasteboard.setString(text, forType: .string)
        self.pasteboard.setData(Data(), forType: self.trimmyMarker)
    }

    private func updateSummary(with text: String) {
        let singleLine = text.replacingOccurrences(of: "\n", with: " ")
        self.lastSummary = ClipboardMonitor.ellipsize(singleLine, limit: 90)
    }

    func trimmedClipboardText(force: Bool = false) -> String? {
        guard let variants = self.makeVariants(force: force, ignoreMarker: force) else { return nil }
        if !force, !variants.wasTransformed { return nil }
        return variants.trimmed
    }

    static func ellipsize(_ text: String, limit: Int) -> String {
        guard limit >= 3, text.count > limit else { return text }
        let keep = limit - 1 // account for ellipsis
        let headCount = keep / 2
        let tailCount = keep - headCount
        let head = text.prefix(headCount)
        let tail = text.suffix(tailCount)
        return "\(head)…\(tail)"
    }

    private func normalizeLineEndings(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    @objc
    private func handleAppActivation(_ notification: Notification) {
        let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
        self.updateFrontmostAppName(app)
    }

    private func updateFrontmostAppName(_ app: NSRunningApplication?) {
        guard let app else {
            self.frontmostAppName = "current app"
            return
        }
        if app.bundleIdentifier == Bundle.main.bundleIdentifier {
            return
        }
        self.frontmostAppName = app.localizedName ?? "current app"
    }
}

// MARK: - On-demand pasting

extension ClipboardMonitor {
    private static let accessibilityPermissionMessage = "Enable Accessibility to let Trimmy paste (System Settings "
        + "→ Privacy & Security → Accessibility)."

    @discardableResult
    func pasteTrimmed() -> Bool {
        guard self.accessibilityPermission.isTrusted else {
            self.lastSummary = Self.accessibilityPermissionMessage
            return false
        }
        guard let variants = self.cachedOrCurrentVariantsForPaste(force: true) else {
            self.lastSummary = "Nothing to paste."
            return false
        }
        self.updateSummary(with: variants.trimmed)
        self.registerTrimEvent()
        self.performPaste(with: variants.trimmed)
        return true
    }

    @discardableResult
    func pasteOriginal() -> Bool {
        guard self.accessibilityPermission.isTrusted else {
            self.lastSummary = Self.accessibilityPermissionMessage
            return false
        }
        guard let original = self.lastOriginalText ?? self.clipboardText() else {
            self.lastSummary = "Nothing to paste."
            return false
        }
        self.lastOriginalText = original
        self.lastTrimmedText = nil
        self.updateSummary(with: original)
        self.performPaste(with: original)
        return true
    }

    func struckOriginalPreview(limit _: Int? = nil) -> AttributedString {
        guard let original = self.lastOriginalText else {
            return AttributedString(self.lastSummary.isEmpty ? "No actions yet" : self.lastSummary)
        }
        let trimmed = self.lastTrimmedText ?? original
        return ClipboardMonitor.struck(original: original, trimmed: trimmed)
    }

    func trimmedPreviewText() -> String {
        if let trimmed = self.lastTrimmedText {
            return PreviewMetrics.displayString(trimmed)
        }
        if !self.lastSummary.isEmpty {
            return PreviewMetrics.displayString(self.lastSummary)
        }
        return "No trimmed text yet"
    }

    func trimmedPreviewSource() -> String? {
        self.lastTrimmedText ?? (self.lastSummary.isEmpty ? nil : self.lastSummary)
    }

    func originalPreviewSource() -> String? {
        self.lastOriginalText
    }
}

// MARK: - Helpers

extension ClipboardMonitor {
    fileprivate struct ClipboardVariants {
        let original: String
        let trimmed: String
        let wasTransformed: Bool
    }

    private func cachedOrCurrentVariantsForPaste(force: Bool) -> ClipboardVariants? {
        if let cachedOriginal = self.lastOriginalText {
            let variants = self.transform(text: cachedOriginal, force: force)
            self.cache(original: cachedOriginal, trimmed: variants.trimmed)
            return variants
        }

        return self.makeVariants(force: force, ignoreMarker: true)
    }

    private func makeVariants(force: Bool, ignoreMarker: Bool) -> ClipboardVariants? {
        guard let text = self.readTextFromPasteboard(ignoreMarker: ignoreMarker || force) else {
            self.cache(original: nil, trimmed: nil)
            return nil
        }

        let variants = self.transform(text: text, force: force)
        self.cache(original: variants.original, trimmed: variants.trimmed)

        if force {
            return variants
        }
        return variants.wasTransformed ? variants : nil
    }

    private func transform(text: String, force: Bool) -> ClipboardVariants {
        var currentText = text
        var wasTransformed = false

        if let cleaned = self.detector.cleanBoxDrawingCharacters(currentText) {
            currentText = cleaned
            wasTransformed = true
        }

        if let promptStripped = self.detector.stripPromptPrefixes(currentText) {
            currentText = promptStripped
            wasTransformed = true
        }

        if let repairedURL = self.detector.repairWrappedURL(currentText) {
            currentText = repairedURL
            wasTransformed = true
        }

        let overrideAggressiveness: Aggressiveness? = force ? .high : nil

        if let commandTransformed = self.detector.transformIfCommand(
            currentText,
            aggressivenessOverride: overrideAggressiveness)
        {
            currentText = commandTransformed
            wasTransformed = true
        }

        return ClipboardVariants(
            original: text,
            trimmed: currentText,
            wasTransformed: wasTransformed)
    }

    private func cache(original: String?, trimmed: String?) {
        self.lastOriginalText = original
        self.lastTrimmedText = trimmed
    }

    private func performPaste(with text: String) {
        let previousString = self.clipboardText()

        self.ignoreChangeWhile {
            self.pasteboard.declareTypes([.string, self.trimmyMarker], owner: nil)
            self.pasteboard.setString(text, forType: .string)
            self.pasteboard.setData(Data(), forType: self.trimmyMarker)
        }

        self.pasteIntoFrontmostApp()

        guard let previousString else { return }
        self.restorePasteboard(string: previousString)
    }

    private func ignoreChangeWhile(_ work: () -> Void) {
        let before = self.pasteboard.changeCount
        work()
        let after = self.pasteboard.changeCount
        if after != before {
            self.ignoredChangeCounts.insert(after)
            self.lastSeenChangeCount = after
        }
    }

    private func restorePasteboard(string: String) {
        DispatchQueue.main.asyncAfter(deadline: .now() + self.pasteRestoreDelay) { [weak self] in
            guard let self else { return }
            self.ignoreChangeWhile {
                self.pasteboard.clearContents()
                self.pasteboard.setString(string, forType: .string)
            }
        }
    }

    fileprivate static func sendPasteCommand() {
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        let keyCode = CGKeyCode(kVK_ANSI_V)

        let down = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)

        let up = CGEvent(keyboardEventSource: source, virtualKey: keyCode, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }

    static func struck(original: String, trimmed: String, limit _: Int? = nil) -> AttributedString {
        let o = Array(original)
        let t = Array(trimmed)

        // Two-pointer diff on the raw strings (no ellipsizing, no visible whitespace yet).
        var i = 0
        var j = 0
        var removedFlags = Array(repeating: false, count: o.count)

        while i < o.count, j < t.count {
            if o[i] == t[j] {
                i += 1
                j += 1
            } else {
                removedFlags[i] = true
                i += 1
            }
        }
        while i < o.count {
            removedFlags[i] = true
            i += 1
        }

        let (mappedString, mappedFlags) = PreviewMetrics.mapToVisibleWhitespace(String(o), removed: removedFlags)
        let base = NSMutableAttributedString(string: mappedString)

        for (idx, isRemoved) in mappedFlags.enumerated() where isRemoved {
            base.addAttributes([
                .strikethroughStyle: NSUnderlineStyle.single.rawValue,
            ], range: NSRange(location: idx, length: 1))
        }

        return AttributedString(base)
    }

    private func registerTrimEvent() {
        self.trimPulseID &+= 1
    }
}

#if DEBUG
extension ClipboardMonitor {
    func triggerTrimPulse() {
        self.registerTrimEvent()
    }

    func debugSetPreview(original: String, trimmed: String) {
        self.lastOriginalText = original
        self.lastTrimmedText = trimmed
        self.updateSummary(with: trimmed)
    }
}
#endif
