import AppKit
import Combine
import SwiftUI

// MARK: - Settings

enum Aggressiveness: String, CaseIterable, Identifiable, Codable {
    case low, normal, high
    var id: String { rawValue }

    var scoreThreshold: Int {
        switch self {
        case .low: 3
        case .normal: 2
        case .high: 1
        }
    }
}

final class AppSettings: ObservableObject {
    @AppStorage("aggressiveness") var aggressiveness: Aggressiveness = .normal
    @AppStorage("preserveBlankLines") var preserveBlankLines: Bool = false
    @AppStorage("autoTrimEnabled") var autoTrimEnabled: Bool = true
}

// MARK: - Command Detection

struct CommandDetector {
    let settings: AppSettings

    func transformIfCommand(_ text: String) -> String? {
        guard text.contains("\n") else { return nil }

        let lines = text.split(whereSeparator: { $0.isNewline })
        guard lines.count >= 2 else { return nil }
        if lines.count > 10 { return nil } // skip very large copies to avoid unintended flattening

        var score = 0
        if text.contains("\n") { score += 1 }
        if text.contains("\\\n") { score += 1 }
        if text.range(of: #"[|&]{1,2}"#, options: .regularExpression) != nil { score += 1 }
        if text.range(of: #"(^|\n)\s*\$"#, options: .regularExpression) != nil { score += 1 }
        if lines.allSatisfy(self.isLikelyCommandLine(_:)) { score += 1 }
        if text.range(of: #"(?m)^\s*(sudo\s+)?[A-Za-z0-9./~_-]+"#, options: .regularExpression) != nil { score += 1 }

        guard score >= self.settings.aggressiveness.scoreThreshold else { return nil }

        let flattened = self.flatten(text)
        return flattened == text ? nil : flattened
    }

    private func isLikelyCommandLine(_ lineSubstr: Substring) -> Bool {
        let line = lineSubstr.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return false }
        if line.last == "." { return false }
        let pattern = #"^(sudo\s+)?[A-Za-z0-9./~_-]+(?:\s+|\z)"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }

    private func flatten(_ text: String) -> String {
        let placeholder = "__BLANK_SEP__"
        var result = text
        if self.settings.preserveBlankLines {
            result = result.replacingOccurrences(of: "\n\\s*\n", with: placeholder, options: .regularExpression)
        }
        // Repair cases where a newline sneaks into a token (e.g., "N\nODE_PATH").
        result = result.replacingOccurrences(
            of: #"(?<!\n)([A-Za-z0-9_.-])\s*\n\s*([A-Za-z0-9_.-])(?!\n)"#,
            with: "$1$2",
            options: .regularExpression)
        // Remove line-continuation backslashes plus newline.
        result = result.replacingOccurrences(of: #"\\\s*\n"#, with: " ", options: .regularExpression)
        // Replace remaining newlines with single spaces.
        result = result.replacingOccurrences(of: "\n", with: " ")
        // Collapse repeated whitespace.
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if self.settings.preserveBlankLines {
            result = result.replacingOccurrences(of: placeholder, with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

// MARK: - Clipboard Monitor

@MainActor
final class ClipboardMonitor: ObservableObject {
    private let settings: AppSettings
    private let pasteboard = NSPasteboard.general
    private let trimmyMarker = NSPasteboard.PasteboardType("dev.peter.trimmy")
    private var timer: DispatchSourceTimer?
    private var lastSeenChangeCount: Int
    private var detector: CommandDetector { CommandDetector(settings: self.settings) }
    private let pollInterval: DispatchTimeInterval = .milliseconds(150)
    private let pollLeeway: DispatchTimeInterval = .milliseconds(50)
    private let graceDelay: DispatchTimeInterval = .milliseconds(80)

    @Published var lastSummary: String = ""

    init(settings: AppSettings) {
        self.settings = settings
        self.lastSeenChangeCount = self.pasteboard.changeCount
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

        guard let text = readTextFromPasteboard() else { return false }
        guard self.settings.autoTrimEnabled || force else { return false }

        let transformed: String
        if force {
            transformed = self.detector.transformIfCommand(text) ?? text
            if transformed == text, !text.contains("\\\n"), !text.contains("\n") { return false }
        } else {
            guard let candidate = detector.transformIfCommand(text) else { return false }
            transformed = candidate
        }

        self.writeTrimmed(transformed)
        self.lastSeenChangeCount = self.pasteboard.changeCount
        self.updateSummary(with: transformed)
        return true
    }

    private func tick() {
        let current = self.pasteboard.changeCount
        guard current != self.lastSeenChangeCount else { return }

        let observed = current
        DispatchQueue.main.asyncAfter(deadline: .now() + self.graceDelay) { [weak self] in
            guard let self else { return }
            guard self.pasteboard.changeCount == observed else { return }
            self.handleChange(observedChangeCount: observed)
        }
    }

    private func handleChange(observedChangeCount: Int) {
        if self.pasteboard.types?.contains(self.trimmyMarker) == true {
            self.lastSeenChangeCount = observedChangeCount
            return
        }

        guard self.settings.autoTrimEnabled else { return }
        guard let text = readTextFromPasteboard(), !text.isEmpty else { return }
        guard let transformed = detector.transformIfCommand(text) else { return }

        self.writeTrimmed(transformed)
        self.lastSeenChangeCount = self.pasteboard.changeCount
        self.updateSummary(with: transformed)
    }

    private func readTextFromPasteboard() -> String? {
        if let items = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           let s = items.first
        {
            return s
        }

        let candidates: [NSPasteboard.PasteboardType] = [
            .string,
            NSPasteboard.PasteboardType("public.utf8-plain-text"),
            NSPasteboard.PasteboardType("public.utf16-external-plain-text"),
        ]
        for t in candidates where self.pasteboard.types?.contains(t) == true {
            if let s = pasteboard.string(forType: t) { return s }
        }
        return nil
    }

    private func writeTrimmed(_ text: String) {
        self.pasteboard.clearContents()
        self.pasteboard.declareTypes([.string, self.trimmyMarker], owner: nil)
        self.pasteboard.setString(text, forType: .string)
        self.pasteboard.setData(Data(), forType: self.trimmyMarker)
    }

    private func updateSummary(with transformed: String) {
        let preview = transformed.prefix(70)
        self.lastSummary = "\(preview)" + (transformed.count > 70 ? "…" : "")
    }
}

// MARK: - SwiftUI Views

struct SettingsView: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        Form {
            Picker("Aggressiveness", selection: self.$settings.aggressiveness) {
                ForEach(Aggressiveness.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            Toggle("Keep blank lines", isOn: self.$settings.preserveBlankLines)
            Toggle("Auto-trim enabled", isOn: self.$settings.autoTrimEnabled)
        }
        .padding()
        .frame(width: 320)
    }
}

extension Aggressiveness {
    fileprivate var title: String {
        switch self {
        case .low: "Low (safer)"
        case .normal: "Normal"
        case .high: "High (more eager)"
        }
    }

    fileprivate var titleShort: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        }
    }
}

struct MenuContentView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Auto-Trim", isOn: self.$settings.autoTrimEnabled)
            Menu {
                ForEach(Aggressiveness.allCases) { level in
                    Button {
                        self.settings.aggressiveness = level
                    } label: {
                        if self.settings.aggressiveness == level {
                            Label(level.title, systemImage: "checkmark")
                        } else {
                            Text(level.title)
                        }
                    }
                }
            } label: {
                Text("Aggressiveness: \(self.settings.aggressiveness.titleShort)")
            }
            Toggle("Keep blank lines", isOn: self.$settings.preserveBlankLines)
            Button("Trim Clipboard Now") {
                self.monitor.trimClipboardIfNeeded(force: true)
            }
            Text(self.settingsSummary)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }

    private var lastText: String {
        self.monitor.lastSummary.isEmpty ? "No trims yet" : "Last: \(self.monitor.lastSummary)"
    }

    private var settingsSummary: String {
        self.lastText
    }
}

// MARK: - App

@main
struct TrimmyApp: App {
    @StateObject private var settings = AppSettings()
    @StateObject private var monitor: ClipboardMonitor

    init() {
        let settings = AppSettings()
        let monitor = ClipboardMonitor(settings: settings)
        monitor.start()
        _settings = StateObject(wrappedValue: settings)
        _monitor = StateObject(wrappedValue: monitor)
    }

    var body: some Scene {
        MenuBarExtra("Trimmy", systemImage: "scissors") {
            MenuContentView(monitor: self.monitor, settings: self.settings)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        Settings {
            SettingsView(settings: self.settings)
        }
    }

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        self.monitor.start()
    }
}
