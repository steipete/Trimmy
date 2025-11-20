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
            Toggle(isOn: self.$settings.autoTrimEnabled) {
                Text("Auto-Trim")
            }
            .toggleStyle(.checkbox)

            self.trimClipboardButton
            VStack(alignment: .leading, spacing: 2) {
                Text("Last:")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                MenuWrappingText(
                    text: self.lastSummary,
                    width: 260,
                    maxLines: 5)
            }
            Divider()
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

    private var lastSummary: String {
        self.monitor.lastSummary.isEmpty ? "No trims yet" : self.monitor.lastSummary
    }

    private func handleTrimClipboard() {
        let didTrim = self.monitor.trimClipboardIfNeeded(force: true)
        if !didTrim {
            self.monitor.lastSummary = "Clipboard not trimmed (nothing command-like detected)."
        }
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
    private var trimClipboardButton: some View {
        Button("Trim Clipboard") {
            self.handleTrimClipboard()
        }
        .applyKeyboardShortcut(self.trimKeyboardShortcut)
    }

    private var trimKeyboardShortcut: KeyboardShortcut? {
        guard self.settings.trimHotkeyEnabled,
              let shortcut = KeyboardShortcuts.getShortcut(for: .trimClipboard) else { return nil }
        return shortcut.swiftUIShortcut
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

// MARK: - Multiline preview helper

private struct MenuWrappingText: NSViewRepresentable {
    var text: String
    var width: CGFloat
    var maxLines: Int
    var font: NSFont = .systemFont(ofSize: NSFont.smallSystemFontSize)
    var color: NSColor = .secondaryLabelColor

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(wrappingLabelWithString: text)
        field.isSelectable = false
        field.backgroundColor = .clear
        field.textColor = self.color
        field.font = self.font
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = self.maxLines
        field.setFrameSize(self.size(for: self.text))
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        field.stringValue = self.text
        field.textColor = self.color
        field.font = self.font
        field.maximumNumberOfLines = self.maxLines
        field.setFrameSize(self.size(for: self.text))
    }

    private func size(for string: String) -> NSSize {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: self.font,
            .paragraphStyle: paragraph,
        ]
        let rect = (string as NSString).boundingRect(
            with: NSSize(width: self.width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes)
        let lineHeight = ceil(font.ascender - self.font.descender + self.font.leading)
        let maxHeight = lineHeight * CGFloat(max(1, self.maxLines))
        return NSSize(width: self.width, height: min(ceil(rect.height), maxHeight))
    }
}
