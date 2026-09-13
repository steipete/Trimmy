import AppKit
import KeyboardShortcuts
import Observation
import SwiftUI

@MainActor
struct MenuContentView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var settings: AppSettings
    @ObservedObject var permissions: AccessibilityPermissionManager
    let updater: UpdaterProviding
    @Bindable private var updateStatus: UpdateStatus

    @Environment(\.openSettings) private var openSettings

    init(
        monitor: ClipboardMonitor,
        settings: AppSettings,
        permissions: AccessibilityPermissionManager,
        updater: UpdaterProviding)
    {
        self._monitor = ObservedObject(wrappedValue: monitor)
        self._settings = ObservedObject(wrappedValue: settings)
        self._permissions = ObservedObject(wrappedValue: permissions)
        self.updater = updater
        self._updateStatus = Bindable(wrappedValue: updater.updateStatus)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if !self.permissions.isTrusted {
                AccessibilityPermissionCallout(permissions: self.permissions, compactButtons: true)
            }
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
            if self.updater.isAvailable, self.updateStatus.isUpdateReady {
                Button("Update ready, restart now?") { self.updater.checkForUpdates(nil) }
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

    private func handlePasteReformattedMarkdown() {
        _ = self.monitor.pasteReformattedMarkdown()
    }

    private func handlePasteStrippingURLQueryParams() {
        _ = self.monitor.pasteStrippingURLQueryParams()
    }

    private var targetAppLabel: String {
        ClipboardMonitor.ellipsize(self.monitor.frontmostAppName, limit: 30)
    }

    private func open(tab: SettingsTab) {
        SettingsTabRouter.request(tab)
        NSApp.activate(ignoringOtherApps: true)
        self.openSettings()
        NotificationCenter.default.post(name: .trimmySelectSettingsTab, object: tab)
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

            if self.settings.showMarkdownReformatOption,
               let markdownPreviewSource = self.markdownPreviewSource
            {
                let markdownStatsSuffix = self.statsSuffix(for: markdownPreviewSource)
                Button("Paste Reflowed Text to \(self.targetAppLabel)\(markdownStatsSuffix)") {
                    self.handlePasteReformattedMarkdown()
                }
                Text(self.previewLine(for: markdownPreviewSource))
                    .font(.caption2).monospaced()
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .truncationMode(.middle)
                    .frame(maxWidth: 260, alignment: .leading)
            }

            if self.settings.showURLQueryParamStripOption,
               let strippedURLPreviewSource = self.strippedURLPreviewSource
            {
                let strippedStatsSuffix = self.statsSuffix(for: strippedURLPreviewSource)
                Button("Paste without Query Params to \(self.targetAppLabel)\(strippedStatsSuffix)") {
                    self.handlePasteStrippingURLQueryParams()
                }
                Text(self.previewLine(for: strippedURLPreviewSource))
                    .font(.caption2).monospaced()
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .truncationMode(.middle)
                    .frame(maxWidth: 260, alignment: .leading)
            }

            Button("Paste Original to \(self.targetAppLabel)\(self.originalStatsSuffix)") {
                self.handlePasteOriginal()
            }
            .applyKeyboardShortcut(self.pasteOriginalKeyboardShortcut)
            Text(self.monitor.struckOriginalPreview())
                .font(.caption2).monospaced()
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .truncationMode(.middle)
                .frame(maxWidth: 260, alignment: .leading)
        }
    }

    var pasteTrimmedKeyboardShortcut: KeyboardShortcut? {
        guard self.settings.pasteTrimmedHotkeyEnabled,
              let shortcut = KeyboardShortcuts.getShortcut(for: .pasteTrimmed) else { return nil }
        return shortcut.toSwiftUI
    }

    private var pasteOriginalKeyboardShortcut: KeyboardShortcut? {
        guard self.settings.pasteOriginalHotkeyEnabled,
              let shortcut = KeyboardShortcuts.getShortcut(for: .pasteOriginal) else { return nil }
        return shortcut.toSwiftUI
    }

    private var trimmedPreviewLine: String {
        ClipboardMonitor.ellipsize(self.monitor.trimmedPreviewText(), limit: MenuPreview.limit)
    }

    private var trimmedStatsSuffix: String {
        self.statsSuffix(for: self.monitor.trimmedPreviewSource())
    }

    private var originalStatsSuffix: String {
        self.statsSuffix(for: self.monitor.originalPreviewSource())
    }

    private func statsSuffix(for text: String?) -> String {
        guard let text else { return "" }
        return PreviewMetrics.prettyBadge(count: text.count)
    }

    private var markdownPreviewSource: String? {
        self.monitor.markdownReformatPreviewSource()
    }

    private var strippedURLPreviewSource: String? {
        self.monitor.urlQueryParamStripPreviewSource()
    }

    private func previewLine(for text: String) -> String {
        ClipboardMonitor.ellipsize(PreviewMetrics.displayString(text), limit: MenuPreview.limit)
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
    static let limit = 30
}
