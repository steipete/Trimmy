import SwiftUI
import AppKit
import Combine

// MARK: - Settings

enum Aggressiveness: String, CaseIterable, Identifiable, Codable {
    case low, normal, high
    var id: String { rawValue }

    var scoreThreshold: Int {
        switch self {
        case .low: return 3
        case .normal: return 2
        case .high: return 1
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

        var score = 0
        if text.contains("\\\n") { score += 1 }
        if text.range(of: #"[|&]{1,2}"#, options: .regularExpression) != nil { score += 1 }
        if text.range(of: #"(^|\n)\s*\$"#, options: .regularExpression) != nil { score += 1 }
        if lines.allSatisfy(isLikelyCommandLine(_:)) { score += 1 }
        if text.range(of: #"(?m)^\s*(sudo\s+)?[A-Za-z0-9./~_-]+"#, options: .regularExpression) != nil { score += 1 }

        guard score >= settings.aggressiveness.scoreThreshold else { return nil }

        let flattened = flatten(text)
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
        if settings.preserveBlankLines {
            result = result.replacingOccurrences(of: "\n\\s*\n", with: placeholder, options: .regularExpression)
        }
        // Remove line-continuation backslashes plus newline.
        result = result.replacingOccurrences(of: #"\\\s*\n"#, with: " ", options: .regularExpression)
        // Replace remaining newlines with single spaces.
        result = result.replacingOccurrences(of: "\n", with: " ")
        // Collapse repeated whitespace.
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if settings.preserveBlankLines {
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
    private var detector: CommandDetector { CommandDetector(settings: settings) }
    private let pollInterval: DispatchTimeInterval = .milliseconds(150)
    private let pollLeeway: DispatchTimeInterval = .milliseconds(50)
    private let graceDelay: DispatchTimeInterval = .milliseconds(80)

    @Published var lastSummary: String = ""

    init(settings: AppSettings) {
        self.settings = settings
        self.lastSeenChangeCount = pasteboard.changeCount
    }

    func start() {
        stop()
        let t = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
        t.schedule(deadline: .now(), repeating: pollInterval, leeway: pollLeeway)
        t.setEventHandler { [weak self] in
            self?.tick()
        }
        t.resume()
        timer = t
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    @discardableResult
    func trimClipboardIfNeeded(force: Bool = false) -> Bool {
        let changeCount = pasteboard.changeCount
        lastSeenChangeCount = changeCount

        guard let text = readTextFromPasteboard() else { return false }
        guard settings.autoTrimEnabled || force else { return false }

        let transformed: String
        if force {
            transformed = detector.transformIfCommand(text) ?? text
            if transformed == text && !text.contains("\\\n") && !text.contains("\n") { return false }
        } else {
            guard let candidate = detector.transformIfCommand(text) else { return false }
            transformed = candidate
        }

        writeTrimmed(transformed)
        lastSeenChangeCount = pasteboard.changeCount
        updateSummary(with: transformed)
        return true
    }

    private func tick() {
        let current = pasteboard.changeCount
        guard current != lastSeenChangeCount else { return }

        let observed = current
        DispatchQueue.main.asyncAfter(deadline: .now() + graceDelay) { [weak self] in
            guard let self else { return }
            guard self.pasteboard.changeCount == observed else { return }
            self.handleChange(observedChangeCount: observed)
        }
    }

    private func handleChange(observedChangeCount: Int) {
        if pasteboard.types?.contains(trimmyMarker) == true {
            lastSeenChangeCount = observedChangeCount
            return
        }

        guard settings.autoTrimEnabled else { return }
        guard let text = readTextFromPasteboard(), !text.isEmpty else { return }
        guard let transformed = detector.transformIfCommand(text) else { return }

        writeTrimmed(transformed)
        lastSeenChangeCount = pasteboard.changeCount
        updateSummary(with: transformed)
    }

    private func readTextFromPasteboard() -> String? {
        if let items = pasteboard.readObjects(forClasses: [NSString.self], options: nil) as? [String],
           let s = items.first {
            return s
        }

        let candidates: [NSPasteboard.PasteboardType] = [
            .string,
            NSPasteboard.PasteboardType("public.utf8-plain-text"),
            NSPasteboard.PasteboardType("public.utf16-external-plain-text")
        ]
        for t in candidates where pasteboard.types?.contains(t) == true {
            if let s = pasteboard.string(forType: t) { return s }
        }
        return nil
    }

    private func writeTrimmed(_ text: String) {
        pasteboard.clearContents()
        pasteboard.declareTypes([.string, trimmyMarker], owner: nil)
        pasteboard.setString(text, forType: .string)
        pasteboard.setData(Data(), forType: trimmyMarker)
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
            Picker("Aggressiveness", selection: $settings.aggressiveness) {
                ForEach(Aggressiveness.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            Toggle("Keep blank lines", isOn: $settings.preserveBlankLines)
            Toggle("Auto-trim enabled", isOn: $settings.autoTrimEnabled)
        }
        .padding()
        .frame(width: 320)
    }
}

private extension Aggressiveness {
    var title: String {
        switch self {
        case .low: return "Low (safer)"
        case .normal: return "Normal"
        case .high: return "High (more eager)"
        }
    }

    var titleShort: String {
        switch self {
        case .low: return "Low"
        case .normal: return "Normal"
        case .high: return "High"
        }
    }
}

struct MenuContentView: View {
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle("Auto-Trim", isOn: $settings.autoTrimEnabled)
            Menu {
                ForEach(Aggressiveness.allCases) { level in
                    Button {
                        settings.aggressiveness = level
                    } label: {
                        if settings.aggressiveness == level {
                            Label(level.title, systemImage: "checkmark")
                        } else {
                            Text(level.title)
                        }
                    }
                }
            } label: {
                Text("Aggressiveness: \(settings.aggressiveness.titleShort)")
            }
            Toggle("Keep blank lines", isOn: $settings.preserveBlankLines)
            Button("Trim Clipboard Now") {
                monitor.trimClipboardIfNeeded(force: true)
            }
            Text(settingsSummary)
                .foregroundStyle(.secondary)
                .font(.caption)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
    }

    private var lastText: String {
        monitor.lastSummary.isEmpty ? "No trims yet" : "Last: \(monitor.lastSummary)"
    }

    private var settingsSummary: String {
        "Aggressiveness: \(settings.aggressiveness.titleShort); Blank lines: \(settings.preserveBlankLines ? "kept" : "removed"); \(lastText)"
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
        MenuBarExtra("✂️ Trimmy") {
            MenuContentView(monitor: monitor, settings: settings)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        }
        Settings {
            SettingsView(settings: settings)
        }
    }

    @MainActor
    func applicationDidFinishLaunching(_ notification: Notification) {
        monitor.start()
    }
}
