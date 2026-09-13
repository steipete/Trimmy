import SwiftUI
import TrimmyCore

@MainActor
struct TrimmingSettingsPane: View {
    @ObservedObject var settings: AppSettings

    var body: some View {
        SettingsPaneLayout {
            SettingsSection(
                "Sensitivity",
                subtitle: "Set how readily Trimmy flattens command-shaped text in regular apps and terminals.")
            {
                VStack(alignment: .leading, spacing: 14) {
                    Grid(alignment: .leading, horizontalSpacing: 18, verticalSpacing: 12) {
                        GridRow {
                            Text("General apps")
                                .frame(minWidth: 120, alignment: .leading)
                            Picker("", selection: self.$settings.generalAggressiveness) {
                                ForEach(GeneralAggressiveness.allCases) { level in
                                    Text(level.title).tag(level)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(minWidth: 190, alignment: .leading)
                        }

                        GridRow {
                            Text("Terminals")
                                .frame(minWidth: 120, alignment: .leading)
                            Picker("", selection: self.$settings.terminalAggressiveness) {
                                ForEach(Aggressiveness.allCases) { level in
                                    Text(level.title).tag(level)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .frame(minWidth: 190, alignment: .leading)
                        }
                    }

                    Divider()

                    PreferenceToggleRow(
                        title: "Use terminal-specific sensitivity",
                        subtitle: "Apply the terminal level when Trimmy detects a terminal copy.",
                        binding: self.$settings.contextAwareTrimmingEnabled)
                }
            }

            SettingsSection(
                "Preview",
                subtitle: "Follows the General apps level and the text cleanup options in Advanced. "
                    + "Manual “Paste Trimmed” always uses High.")
            {
                AggressivenessPreview(
                    level: self.settings.generalAggressiveness,
                    preserveBlankLines: self.settings.preserveBlankLines,
                    removeBoxDrawing: self.settings.removeBoxDrawing)
            }
        }
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

            ViewThatFits(in: .horizontal) {
                HStack(alignment: .top, spacing: 12) {
                    PreviewCard(title: "Before", text: self.example.sample)
                    Divider()
                    PreviewCard(
                        title: "After",
                        text: AggressivenessPreviewEngine.previewAfter(
                            for: self.example.sample,
                            level: self.level.coreAggressiveness,
                            preserveBlankLines: self.preserveBlankLines,
                            removeBoxDrawing: self.removeBoxDrawing))
                }

                VStack(alignment: .leading, spacing: 8) {
                    PreviewCard(title: "Before", text: self.example.sample)
                    Divider()
                    PreviewCard(
                        title: "After",
                        text: AggressivenessPreviewEngine.previewAfter(
                            for: self.example.sample,
                            level: self.level.coreAggressiveness,
                            preserveBlankLines: self.preserveBlankLines,
                            removeBoxDrawing: self.removeBoxDrawing))
                }
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
        TextCleaner().transform(
            sample,
            config: TrimConfig(
                aggressiveness: level ?? .normal,
                preserveBlankLines: preserveBlankLines,
                removeBoxDrawing: removeBoxDrawing),
            commandFlatteningEnabled: level != nil,
            paragraphDedentEnabled: true).trimmed
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
                title: "None skips command flattening",
                caption: "Commands stay multiline in non-terminal apps. Optional text reflow still applies.",
                sample: """
                brew update \\
                  && brew upgrade
                """,
                note: "Manual “Paste Trimmed” still uses High, and terminals use their own level.")
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
                caption: "Perfect for README snippets with pipes or continuations.",
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
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
