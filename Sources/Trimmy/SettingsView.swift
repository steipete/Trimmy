import AppKit
import KeyboardShortcuts
import SwiftUI

#if DEBUG
private let isDebugBuild = true
#else
private let isDebugBuild = false
#endif

@MainActor
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var hotkeyManager: HotkeyManager
    weak var updater: UpdaterProviding?
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: self.$selectedTab) {
            GeneralSettingsPane(settings: self.settings)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            AggressivenessSettingsPane(settings: self.settings)
                .tabItem { Label("Aggressiveness", systemImage: "speedometer") }
                .tag(SettingsTab.aggressiveness)

            HotkeySettingsPane(settings: self.settings, hotkeyManager: self.hotkeyManager)
                .tabItem { Label("Shortcuts", systemImage: "command") }
                .tag(SettingsTab.shortcuts)

            AboutPane(updater: self.updater)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .padding(12)
        .frame(width: SettingsTab.windowWidth, height: SettingsTab.windowHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: .trimmySelectSettingsTab)) { notification in
            guard let tab = notification.object as? SettingsTab else { return }
            self.select(tab, animate: true)
        }
        .onAppear {
            let initial = SettingsTabRouter.consumePending() ?? self.selectedTab
            self.select(initial, animate: false)
        }
    }

    private func select(_ tab: SettingsTab, animate: Bool) {
        if animate {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                self.selectedTab = tab
            }
        } else {
            self.selectedTab = tab
        }
    }

}

enum SettingsTab: String, Hashable, CaseIterable, Codable {
    case general, aggressiveness, shortcuts, about

    static let windowWidth: CGFloat = 400
    static let windowHeight: CGFloat = 378
}

extension Notification.Name {
    static let trimmySelectSettingsTab = Notification.Name("trimmySelectSettingsTab")
}

@MainActor
enum SettingsTabRouter {
    private static var pending: SettingsTab?

    static func request(_ tab: SettingsTab) {
        self.pending = tab
    }

    static func consumePending() -> SettingsTab? {
        defer { self.pending = nil }
        return self.pending
    }
}

@MainActor
struct GeneralSettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PreferenceToggleRow(
                title: "Auto-trim enabled",
                subtitle: "Automatically trim clipboard content when it looks like a command.",
                binding: self.$settings.autoTrimEnabled)

            PreferenceToggleRow(
                title: "Keep blank lines",
                subtitle: "Preserve intentional blank lines instead of collapsing them.",
                binding: self.$settings.preserveBlankLines)

            PreferenceToggleRow(
                title: "Remove box drawing chars (│ │)",
                subtitle: "Strip prompt-style box borders before trimming.",
                binding: self.$settings.removeBoxDrawing)

            Divider()
                .padding(.vertical, 4)

            PreferenceToggleRow(
                title: "Launch at login",
                subtitle: nil,
                binding: self.$settings.launchAtLogin)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

@MainActor
struct AggressivenessSettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            AggressivenessRow(selection: self.$settings.aggressiveness)

            AggressivenessPreview(
                level: self.settings.aggressiveness,
                preserveBlankLines: self.settings.preserveBlankLines,
                removeBoxDrawing: self.settings.removeBoxDrawing)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

@MainActor
struct AboutPane: View {
    weak var updater: UpdaterProviding?

    private var versionString: String {
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "–"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String
        return build.map { "\(version) (\($0))" } ?? version
    }

    @State private var iconHover: Bool = false
    @State private var autoCheckEnabled: Bool = false
    @State private var didLoadUpdaterState = false
    var body: some View {
        VStack(spacing: 8) {
            if let image = NSApplication.shared.applicationIconImage {
                Button {
                    if let url = URL(string: "https://github.com/steipete/Trimmy") {
                        NSWorkspace.shared.open(url)
                    }
                } label: {
                    Image(nsImage: image)
                        .resizable()
                        .frame(width: 88, height: 88)
                        .cornerRadius(16)
                        .scaleEffect(self.iconHover ? 1.07 : 1.0)
                        .shadow(color: self.iconHover ? .accentColor.opacity(0.25) : .clear, radius: 6)
                }
                .buttonStyle(.plain)
                .onHover { hovering in
                    withAnimation(.spring(response: 0.32, dampingFraction: 0.72, blendDuration: 0.2)) {
                        self.iconHover = hovering
                    }
                }
            }

            VStack(spacing: 2) {
                Text("Trimmy")
                    .font(.title3).bold()
                Text("Version \(self.versionString)")
                    .foregroundStyle(.secondary)
                Text("Paste-once, run-once clipboard cleaner for terminal snippets.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .center, spacing: 6) {
                AboutLinkRow(icon: "chevron.left.slash.chevron.right", title: "GitHub", url: "https://github.com/steipete/Trimmy")
                AboutLinkRow(icon: "globe", title: "Website", url: "https://steipete.me")
                AboutLinkRow(icon: "bird", title: "Twitter", url: "https://twitter.com/steipete")
                AboutLinkRow(icon: "envelope", title: "Email", url: "mailto:peter@steipete.me")
            }
            .frame(maxWidth: .infinity)
            .multilineTextAlignment(.center)

            if let updater {
                Divider()
                if updater.isAvailable {
                    VStack(spacing: 10) {
                        Toggle("Check for updates automatically", isOn: self.$autoCheckEnabled)
                            .toggleStyle(.checkbox)
                            .frame(maxWidth: .infinity, alignment: .center)

                        Button("Check for Updates…") { updater.checkForUpdates(nil) }
                    }
                } else {
                    Text("Updates unavailable in this build.")
                        .foregroundStyle(.secondary)
                        .padding(.top, 4)
                }
            }

            Text("© 2025 Peter Steinberger. MIT License.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.top, 4)
        .padding(.horizontal, 24)
        .padding(.bottom, 24)
        .onAppear {
            guard let updater, !self.didLoadUpdaterState else { return }
            self.autoCheckEnabled = updater.automaticallyChecksForUpdates
            self.didLoadUpdaterState = true
        }
        .onChange(of: self.autoCheckEnabled) { _, newValue in
            self.updater?.automaticallyChecksForUpdates = newValue
        }
    }
}

@MainActor
struct HotkeySettingsPane: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var hotkeyManager: HotkeyManager

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            PreferenceToggleRow(
                title: "Enable global “Type Trimmed” hotkey",
                subtitle: "Lets you type the trimmed clipboard text anywhere via the shortcut.",
                binding: self.$settings.hotkeyEnabled)

            VStack(alignment: .leading, spacing: 6) {
                KeyboardShortcuts.Recorder("", name: .typeTrimmed)
                    .labelsHidden()
                Text("Click to record a shortcut, then use it to type the latest trimmed clipboard text.")
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
            }
        }
        .onChange(of: self.settings.hotkeyEnabled) { _, _ in
            self.hotkeyManager.refreshRegistration()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

// MARK: - Reusable rows

@MainActor
private struct PreferenceToggleRow: View {
    let title: String
    let subtitle: String?
    @Binding var binding: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Toggle(isOn: self.$binding) {
                Text(self.title)
                    .font(.body)
            }
            .toggleStyle(.checkbox)

            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.footnote)
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

@MainActor
private struct AggressivenessRow: View {
    @Binding var selection: Aggressiveness

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Picker("", selection: self.$selection) {
                ForEach(Aggressiveness.allCases) { level in
                    Text(level.title).tag(level)
                }
            }
            .pickerStyle(.radioGroup)

            Text(self.selection.blurb)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

@MainActor
private struct AggressivenessPreview: View {
    let level: Aggressiveness
    let preserveBlankLines: Bool
    let removeBoxDrawing: Bool

    private var example: AggressivenessExample {
        AggressivenessExample.example(for: self.level)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(self.example.title)
                .font(.subheadline.weight(.semibold))

            Text(self.example.caption)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            VStack(alignment: .leading, spacing: 8) {
                PreviewCard(title: "Before", text: self.example.sample)
                PreviewCard(
                    title: "After",
                    text: AggressivenessPreviewEngine.previewAfter(
                        for: self.example.sample,
                        level: self.level,
                        preserveBlankLines: self.preserveBlankLines,
                        removeBoxDrawing: self.removeBoxDrawing))
            }

            if let note = self.example.note {
                Text(note)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

}

enum AggressivenessPreviewEngine {
    static func previewAfter(
        for sample: String,
        level: Aggressiveness,
        preserveBlankLines: Bool,
        removeBoxDrawing: Bool) -> String
    {
        var text = sample
        if removeBoxDrawing {
            text = text.replacingOccurrences(of: "│ │", with: " ")
        }
        let score = self.score(for: text)
        guard score >= level.scoreThreshold else { return text }
        return self.flatten(text, preserveBlankLines: preserveBlankLines)
    }

    static func score(for text: String) -> Int {
        guard text.contains("\n") else { return 0 }
        let lines = text.split(whereSeparator: { $0.isNewline })
        if lines.count < 2 || lines.count > 10 { return 0 }

        var score = 0
        if text.contains("\\\n") { score += 1 }
        if text.range(of: #"[|&]{1,2}"#, options: .regularExpression) != nil { score += 1 }
        if text.range(of: #"(^|\n)\s*\$"#, options: .regularExpression) != nil { score += 1 }
        if text.range(of: #"(?m)^\s*(sudo\s+)?[A-Za-z0-9./~_-]+"#, options: .regularExpression) != nil { score += 1 }
        if text.range(of: #"[-/]"#, options: .regularExpression) != nil { score += 1 }
        return score
    }

    static func flatten(_ text: String, preserveBlankLines: Bool) -> String {
        let placeholder = "__BLANK_SEP__"
        var result = text
        if preserveBlankLines {
            result = result.replacingOccurrences(of: "\n\\s*\n", with: placeholder, options: .regularExpression)
        }
        result = result.replacingOccurrences(
            of: #"(?<!\n)([A-Z0-9_.-])\s*\n\s*([A-Z0-9_.-])(?!\n)"#,
            with: "$1$2",
            options: .regularExpression)
        result = result.replacingOccurrences(of: #"\\\s*\n"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\n+"#, with: " ", options: .regularExpression)
        result = result.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
        if preserveBlankLines {
            result = result.replacingOccurrences(of: placeholder, with: "\n\n")
        }
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}

struct AggressivenessExample {
    let title: String
    let caption: String
    let sample: String
    let note: String?

    static func example(for level: Aggressiveness) -> AggressivenessExample {
        switch level {
        case .low:
            AggressivenessExample(
                title: "Low only flattens obvious shell commands",
                caption: "Continuations plus pipes are obvious enough to collapse.",
                sample: """
ls -la \\
  | grep '^d' \\
  > dirs.txt
""",
                note: "Because of the continuation, pipe, and redirect, even Low collapses this into one line.")
        case .normal:
            AggressivenessExample(
                title: "Normal flattens typical blog commands",
                caption: "Perfect for README/Stack Overflow snippets with pipes or continuations.",
                sample: """
kubectl get pods \\
  -n kube-system \\
  | jq '.items[].metadata.name'
""",
                note: "Normal trims this to a single runnable line.")
        case .high:
            AggressivenessExample(
                title: "High collapses almost anything command-shaped",
                caption: "Use when you want Trimmy to be bold. Even short two-liners get flattened.",
                sample: """
echo "hello"
print status
""",
                note: "High trims this even though it barely looks like a command.")
        }
    }
}

@MainActor
private struct PreviewCard: View {
    let title: String
    let text: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(self.title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(self.text)
                .font(.system(.body, design: .monospaced))
                .frame(maxWidth: .infinity, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(.quinary)
        .cornerRadius(8)
    }
}

// MARK: - About helpers

@MainActor
private struct AboutLinkRow: View {
    let icon: String
    let title: String
    let url: String

    @State private var hovering: Bool = false

    var body: some View {
        Button {
            if let url = URL(string: self.url) {
                NSWorkspace.shared.open(url)
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: self.icon)
                Text(self.title)
                    .underline(self.hovering, color: .accentColor)
            }
            .foregroundColor(.accentColor)
        }
        .buttonStyle(.plain)
        .onHover { self.hovering = $0 }
    }
}
