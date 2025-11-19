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
            self.typeClipboardButton
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

    private func handleTypeClipboard() {
        _ = self.hotkeyManager.typeTrimmedTextNow()
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

private extension MenuContentView {
    var trimClipboardButton: some View {
        Button("Trim Clipboard") {
            self.handleTrimClipboard()
        }
        .applyKeyboardShortcut(self.trimKeyboardShortcut)
    }

    var typeClipboardButton: some View {
        Button("Type Clipboard Text") {
            self.handleTypeClipboard()
        }
        .applyKeyboardShortcut(self.typeKeyboardShortcut)
        .disabled(!self.hasClipboardText)
    }

    var hasClipboardText: Bool {
        self.monitor.clipboardText() != nil
    }

    var typeKeyboardShortcut: KeyboardShortcut? {
        guard self.settings.hotkeyEnabled,
              let shortcut = KeyboardShortcuts.getShortcut(for: .typeTrimmed) else { return nil }
        return shortcut.swiftUIShortcut
    }

    var trimKeyboardShortcut: KeyboardShortcut? {
        guard self.settings.trimHotkeyEnabled,
              let shortcut = KeyboardShortcuts.getShortcut(for: .trimClipboard) else { return nil }
        return shortcut.swiftUIShortcut
    }
}

private extension View {
    @ViewBuilder
    func applyKeyboardShortcut(_ shortcut: KeyboardShortcut?) -> some View {
        if let shortcut {
            self.keyboardShortcut(shortcut)
        } else {
            self
        }
    }
}

private extension KeyboardShortcuts.Shortcut {
    var swiftUIShortcut: KeyboardShortcut? {
        guard let keyEquivalent = self.key?.swiftUIKeyEquivalent else { return nil }
        let modifiers = EventModifiers(self.modifiers)
        return KeyboardShortcut(keyEquivalent, modifiers: modifiers)
    }
}

private extension KeyboardShortcuts.Key {
    var swiftUIKeyEquivalent: KeyEquivalent? {
        switch self {
        case .a: return KeyEquivalent("a")
        case .b: return KeyEquivalent("b")
        case .c: return KeyEquivalent("c")
        case .d: return KeyEquivalent("d")
        case .e: return KeyEquivalent("e")
        case .f: return KeyEquivalent("f")
        case .g: return KeyEquivalent("g")
        case .h: return KeyEquivalent("h")
        case .i: return KeyEquivalent("i")
        case .j: return KeyEquivalent("j")
        case .k: return KeyEquivalent("k")
        case .l: return KeyEquivalent("l")
        case .m: return KeyEquivalent("m")
        case .n: return KeyEquivalent("n")
        case .o: return KeyEquivalent("o")
        case .p: return KeyEquivalent("p")
        case .q: return KeyEquivalent("q")
        case .r: return KeyEquivalent("r")
        case .s: return KeyEquivalent("s")
        case .t: return KeyEquivalent("t")
        case .u: return KeyEquivalent("u")
        case .v: return KeyEquivalent("v")
        case .w: return KeyEquivalent("w")
        case .x: return KeyEquivalent("x")
        case .y: return KeyEquivalent("y")
        case .z: return KeyEquivalent("z")
        case .zero: return KeyEquivalent("0")
        case .one: return KeyEquivalent("1")
        case .two: return KeyEquivalent("2")
        case .three: return KeyEquivalent("3")
        case .four: return KeyEquivalent("4")
        case .five: return KeyEquivalent("5")
        case .six: return KeyEquivalent("6")
        case .seven: return KeyEquivalent("7")
        case .eight: return KeyEquivalent("8")
        case .nine: return KeyEquivalent("9")
        case .comma: return KeyEquivalent(",")
        case .period: return KeyEquivalent(".")
        case .slash: return KeyEquivalent("/")
        case .semicolon: return KeyEquivalent(";")
        case .quote: return KeyEquivalent("\"")
        case .leftBracket: return KeyEquivalent("[")
        case .rightBracket: return KeyEquivalent("]")
        case .minus: return KeyEquivalent("-")
        case .equal: return KeyEquivalent("=")
        case .space: return .space
        case .tab: return .tab
        case .return: return .return
        case .escape: return .escape
        default: return nil
        }
    }
}

private extension EventModifiers {
    init(_ flags: NSEvent.ModifierFlags) {
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
        field.textColor = color
        field.font = font
        field.lineBreakMode = .byWordWrapping
        field.maximumNumberOfLines = maxLines
        field.setFrameSize(self.size(for: text))
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        field.stringValue = text
        field.textColor = color
        field.font = font
        field.maximumNumberOfLines = maxLines
        field.setFrameSize(self.size(for: text))
    }

    private func size(for string: String) -> NSSize {
        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping
        let attributes: [NSAttributedString.Key: Any] = [
            .font: font,
            .paragraphStyle: paragraph,
        ]
        let rect = (string as NSString).boundingRect(
            with: NSSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attributes)
        let lineHeight = ceil(font.ascender - font.descender + font.leading)
        let maxHeight = lineHeight * CGFloat(max(1, maxLines))
        return NSSize(width: width, height: min(ceil(rect.height), maxHeight))
    }
}
