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
            Button("Trim Clipboard") {
                self.handleTrimClipboard()
            }
            Button {
                self.handleTypeClipboard()
            } label: {
                if let shortcut = KeyboardShortcuts.getShortcut(for: .typeTrimmed),
                   self.settings.hotkeyEnabled {
                    HStack {
                        Text("Type Clipboard Text")
                        Spacer()
                        Text(shortcut.description)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text("Type Clipboard Text")
                }
            }
            .disabled(!self.hotkeyManager.hasClipboardText)
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
            Divider()
            Button("Quit Trimmy") {
                NSApplication.shared.terminate(nil)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }

    private var lastSummary: String {
        self.monitor.lastSummary.isEmpty ? "No trims yet" : self.monitor.lastSummary
    }

    private func handleTrimClipboard() {
        NSApp.activate(ignoringOtherApps: true)
        let didTrim = self.monitor.trimClipboardIfNeeded(force: true)
        if !didTrim {
            self.monitor.lastSummary = "Clipboard not trimmed (nothing command-like detected)."
        }
    }

    private func handleTypeClipboard() {
        NSApp.activate(ignoringOtherApps: true)
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
