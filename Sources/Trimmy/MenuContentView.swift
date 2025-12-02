import AppKit
import KeyboardShortcuts
import Sparkle
import SwiftUI

@MainActor
struct MenuContentView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var settings: AppSettings
    @ObservedObject var hotkeyManager: HotkeyManager
    let updater: UpdaterProviding

    @Environment(\.openSettings) private var openSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            self.pasteButtons
            Divider()
            Toggle(isOn: self.$settings.autoTrimEnabled) {
                Text("Auto-Trim")
            }
            .toggleStyle(.checkbox)
            Button("Settings…") {
                self.open(tab: .general)
            }
            .keyboardShortcut(",", modifiers: [.command])
            Button("About Trimmy") {
                self.open(tab: .about)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }

    private func handlePasteTrimmed() {
        _ = self.monitor.pasteTrimmed()
    }

    private func handlePasteOriginal() {
        _ = self.monitor.pasteOriginal()
    }

    private var targetAppLabel: String {
        ClipboardMonitor.ellipsize(self.monitor.frontmostAppName, limit: 30)
    }

    private var previewLine: Text {
        Text(self.monitor.struckOriginalPreview())
    }

    private func open(tab: SettingsTab) {
        SettingsTabRouter.request(tab)
        NSApp.activate(ignoringOtherApps: true)
        self.openSettings()
        NotificationCenter.default.post(name: .trimmySelectSettingsTab, object: tab)
    }

    private func showAbout() {
        NSApp.activate(ignoringOtherApps: true)

        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? ""
        let versionString = build.isEmpty ? version : "\(version) (\(build))"
        let credits = NSMutableAttributedString(string: "Peter Steinberger — MIT License\n")
        credits.append(self.makeLink("GitHub", urlString: "https://github.com/steipete/Trimmy"))
        credits.append(self.separator)
        credits.append(self.makeLink("Website", urlString: "https://steipete.me"))
        credits.append(self.separator)
        credits.append(self.makeLink("Twitter", urlString: "https://twitter.com/steipete"))
        credits.append(self.separator)
        credits.append(self.makeLink("Email", urlString: "mailto:peter@steipete.me"))

        let options: [NSApplication.AboutPanelOptionKey: Any] = [
            .applicationName: "Trimmy",
            .applicationVersion: versionString,
            .version: versionString,
            .credits: credits,
            .applicationIcon: (NSApplication.shared.applicationIconImage ?? NSImage()) as Any,
        ]

        NSApplication.shared.orderFrontStandardAboutPanel(options: options)
    }

    private func makeLink(_ title: String, urlString: String) -> NSAttributedString {
        let attributes: [NSAttributedString.Key: Any] = [
            .link: URL(string: urlString) as Any,
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
        ]
        return NSAttributedString(string: title, attributes: attributes)
    }

    private var separator: NSAttributedString {
        NSAttributedString(string: " · ", attributes: [
            .font: NSFont.systemFont(ofSize: NSFont.smallSystemFontSize),
        ])
    }
}

extension MenuContentView {
    private var pasteButtons: some View {
        VStack(alignment: .leading, spacing: 4) {
            Button("Paste Trimmed to \(self.targetAppLabel)\(self.trimmedStatsSuffix)") {
                self.handlePasteTrimmed()
            }
            .applyKeyboardShortcut(self.pasteTrimmedKeyboardShortcut)
            Text(self.trimmedPreviewLine)
                .font(.caption2).monospaced()
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .truncationMode(.middle)
                .frame(maxWidth: 260, alignment: .leading)

            Button("Paste Original to \(self.targetAppLabel)\(self.originalStatsSuffix)") {
                self.handlePasteOriginal()
            }
            .applyKeyboardShortcut(self.pasteOriginalKeyboardShortcut)
            Text(self.monitor.struckOriginalPreview(limit: MenuPreview.limit))
                .font(.caption2).monospaced()
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .truncationMode(.middle)
                .frame(maxWidth: 260, alignment: .leading)
        }
    }

    private var pasteTrimmedKeyboardShortcut: KeyboardShortcut? {
        guard self.settings.pasteTrimmedHotkeyEnabled,
              let shortcut = KeyboardShortcuts.getShortcut(for: .pasteTrimmed) else { return nil }
        return shortcut.swiftUIShortcut
    }

    private var pasteOriginalKeyboardShortcut: KeyboardShortcut? {
        guard self.settings.pasteOriginalHotkeyEnabled,
              let shortcut = KeyboardShortcuts.getShortcut(for: .pasteOriginal) else { return nil }
        return shortcut.swiftUIShortcut
    }

    private var trimmedPreviewLine: String {
        ClipboardMonitor.ellipsize(self.monitor.trimmedPreviewText(), limit: MenuPreview.limit)
    }

    private var trimmedStatsSuffix: String {
        guard let trimmed = self.monitor.trimmedPreviewSource() else { return "" }
        let base = PreviewMetrics.prettyBadge(
            count: trimmed.count,
            limit: MenuPreview.limit,
            showTruncations: true)
        if let original = self.monitor.originalPreviewSource(),
           original.count > trimmed.count
        {
            let removed = original.count - trimmed.count
            return "\(base) · \(removed) trimmed"
        }
        return base
    }

    private var originalStatsSuffix: String {
        // Show length for the original, but don’t report “trimmed” counts since it is the unmodified text.
        self.statsSuffix(for: self.monitor.originalPreviewSource(), showTruncations: false)
    }

    private func statsSuffix(for text: String?, showTruncations: Bool) -> String {
        guard let text else { return "" }
        return PreviewMetrics.prettyBadge(
            count: text.count,
            limit: MenuPreview.limit,
            showTruncations: showTruncations)
    }
}

extension View {
    @ViewBuilder
    fileprivate func applyKeyboardShortcut(_ shortcut: KeyboardShortcut?) -> some View {
        if let shortcut {
            self.keyboardShortcut(shortcut)
        } else {
            self
        }
    }
}

private enum MenuPreview {
    static let limit = 100
}

extension KeyboardShortcuts.Shortcut {
    fileprivate var swiftUIShortcut: KeyboardShortcut? {
        guard let keyEquivalent = self.key?.swiftUIKeyEquivalent else { return nil }
        let modifiers = EventModifiers(self.modifiers)
        return KeyboardShortcut(keyEquivalent, modifiers: modifiers)
    }
}

extension KeyboardShortcuts.Key {
    fileprivate var swiftUIKeyEquivalent: KeyEquivalent? {
        switch self {
        case .a: KeyEquivalent("a")
        case .b: KeyEquivalent("b")
        case .c: KeyEquivalent("c")
        case .d: KeyEquivalent("d")
        case .e: KeyEquivalent("e")
        case .f: KeyEquivalent("f")
        case .g: KeyEquivalent("g")
        case .h: KeyEquivalent("h")
        case .i: KeyEquivalent("i")
        case .j: KeyEquivalent("j")
        case .k: KeyEquivalent("k")
        case .l: KeyEquivalent("l")
        case .m: KeyEquivalent("m")
        case .n: KeyEquivalent("n")
        case .o: KeyEquivalent("o")
        case .p: KeyEquivalent("p")
        case .q: KeyEquivalent("q")
        case .r: KeyEquivalent("r")
        case .s: KeyEquivalent("s")
        case .t: KeyEquivalent("t")
        case .u: KeyEquivalent("u")
        case .v: KeyEquivalent("v")
        case .w: KeyEquivalent("w")
        case .x: KeyEquivalent("x")
        case .y: KeyEquivalent("y")
        case .z: KeyEquivalent("z")
        case .zero: KeyEquivalent("0")
        case .one: KeyEquivalent("1")
        case .two: KeyEquivalent("2")
        case .three: KeyEquivalent("3")
        case .four: KeyEquivalent("4")
        case .five: KeyEquivalent("5")
        case .six: KeyEquivalent("6")
        case .seven: KeyEquivalent("7")
        case .eight: KeyEquivalent("8")
        case .nine: KeyEquivalent("9")
        case .comma: KeyEquivalent(",")
        case .period: KeyEquivalent(".")
        case .slash: KeyEquivalent("/")
        case .semicolon: KeyEquivalent(";")
        case .quote: KeyEquivalent("\"")
        case .leftBracket: KeyEquivalent("[")
        case .rightBracket: KeyEquivalent("]")
        case .minus: KeyEquivalent("-")
        case .equal: KeyEquivalent("=")
        case .space: .space
        case .tab: .tab
        case .return: .return
        case .escape: .escape
        default: nil
        }
    }
}

extension EventModifiers {
    fileprivate init(_ flags: NSEvent.ModifierFlags) {
        var value: EventModifiers = []
        if flags.contains(.command) { value.insert(.command) }
        if flags.contains(.option) { value.insert(.option) }
        if flags.contains(.control) { value.insert(.control) }
        if flags.contains(.shift) { value.insert(.shift) }
        self = value
    }
}

// Previously used an AppKit wrapping label; we now rely on SwiftUI Text to avoid menu rendering issues.
