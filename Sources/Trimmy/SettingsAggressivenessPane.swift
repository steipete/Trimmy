import SwiftUI
import TrimmyCore

@MainActor
struct AggressivenessSettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                GridRow {
                    Text("Allgemeine Apps")
                        .frame(minWidth: 110, alignment: .leading)
                    Picker("", selection: self.$settings.generalAggressiveness) {
                        ForEach(GeneralAggressiveness.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(minWidth: 180, alignment: .leading)
                }

                GridRow {
                    Text("Terminals")
                        .frame(minWidth: 110, alignment: .leading)
                    Picker("", selection: self.$settings.terminalAggressiveness) {
                        ForEach(Aggressiveness.allCases) { level in
                            Text(level.title).tag(level)
                        }
                    }
                    .labelsHidden()
                    .pickerStyle(.menu)
                    .frame(minWidth: 180, alignment: .leading)
                }
            }

            Text(
                “””
                Automatisches Trimmen verwendet separate Aggressivitätsstufen für normale Apps und Terminals. \
                Die Terminal-Einstellung gilt nur bei aktiviertem kontextabhängigem Trimmen. „Keine” deaktiviert \
                das Befehlsflattening für normale Apps, aber manuelles „Getrimmt einfügen” nutzt immer Hoch. \
                Niedrig/Normal überspringen code-ähnliche Snippets (Klammern + Schlüsselwörter), außer bei \
                starken Befehlshinweisen. Führende Shell-Prompts (#/$) werden entfernt, wenn sie wie Befehle \
                aussehen, aber Markdown-Überschriften bleiben erhalten.
                “””)
                .font(.footnote)
                .foregroundStyle(.tertiary)
                .fixedSize(horizontal: false, vertical: true)

            AggressivenessPreview(
                level: self.settings.generalAggressiveness,
                preserveBlankLines: self.settings.preserveBlankLines,
                removeBoxDrawing: self.settings.removeBoxDrawing)
                .padding(.top, 2)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 12)
    }
}

@MainActor
struct AggressivenessPreview: View {
    let level: GeneralAggressiveness
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
                PreviewCard(title: "Vorher", text: self.example.sample)
                PreviewCard(
                    title: "Nachher",
                    text: AggressivenessPreviewEngine.previewAfter(
                        for: self.example.sample,
                        level: self.level.coreAggressiveness,
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
        level: Aggressiveness?,
        preserveBlankLines: Bool,
        removeBoxDrawing: Bool) -> String
    {
        var text = sample
        if removeBoxDrawing {
            text = CommandDetector.stripBoxDrawingCharacters(in: text) ?? text
        }
        guard let level else { return text }
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
        result = result.replacingOccurrences(
            of: #"(?<=[/~])\s*\n\s*([A-Za-z0-9._-])"#,
            with: "$1",
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

    static func example(for level: GeneralAggressiveness) -> AggressivenessExample {
        switch level {
        case .none:
            AggressivenessExample(
                title: “Keine: Kopien aus normalen Apps bleiben unverändert”,
                caption: “Auto-Trim bleibt für Nicht-Terminal-Apps deaktiviert.”,
                sample: “””
                brew update \\
                  && brew upgrade
                “””,
                note: “Manuelles „Getrimmt einfügen” nutzt weiterhin Hoch, und Terminals verwenden ihre eigene Stufe.”)
        case .low:
            self.example(for: Aggressiveness.low)
        case .normal:
            self.example(for: Aggressiveness.normal)
        case .high:
            self.example(for: Aggressiveness.high)
        }
    }

    static func example(for level: Aggressiveness) -> AggressivenessExample {
        switch level {
        case .low:
            AggressivenessExample(
                title: "Niedrig: Nur offensichtliche Shell-Befehle zusammenfalten",
                caption: "Fortsetzungen und Pipes sind offensichtlich genug zum Zusammenfalten.",
                sample: """
                ls -la \\
                  | grep '^d' \\
                  > dirs.txt
                """,
                note: "Wegen Fortsetzung, Pipe und Redirect faltet selbst Niedrig dies in eine Zeile zusammen.")
        case .normal:
            AggressivenessExample(
                title: "Normal: Typische Blog-Befehle zusammenfalten",
                caption: "Perfekt für README-Snippets mit Pipes oder Fortsetzungen.",
                sample: """
                kubectl get pods \\
                  -n kube-system \\
                  | jq '.items[].metadata.name'
                """,
                note: "Normal trimmt dies zu einer einzigen ausführbaren Zeile.")
        case .high:
            AggressivenessExample(
                title: "Hoch: Fast alles Befehlsähnliche zusammenfalten",
                caption: "Wenn Trimmy mutig sein soll. Selbst kurze Zweizeiler werden zusammengefaltet.",
                sample: """
                echo "hello"
                print status
                """,
                note: "Hoch trimmt dies, obwohl es kaum wie ein Befehl aussieht.")
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
