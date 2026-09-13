import Foundation
import TrimmyCore

@MainActor
struct CommandDetector {
    let settings: AppSettings
    private let cleaner = TextCleaner()

    func transform(
        _ text: String,
        aggressiveness: Aggressiveness?,
        aggressivenessOverride: Aggressiveness? = nil) -> TrimResult
    {
        self.cleaner.transform(
            text,
            config: self.config(aggressiveness: aggressiveness ?? .low),
            aggressivenessOverride: aggressivenessOverride,
            commandFlatteningEnabled: aggressiveness != nil,
            paragraphDedentEnabled: false)
    }

    func stripURLQueryParams(_ text: String) -> String? {
        let rules = self.settings.parsedURLQueryParamRules
        return self.cleaner.stripURLQueryParams(text) { host in
            URLQueryParamRules.keepParams(for: host, customRules: rules)
        }
    }

    func dedentParagraphIndent(_ text: String) -> String? {
        self.cleaner.dedentParagraphIndent(text)
    }

    nonisolated static func stripBoxDrawingCharacters(in text: String) -> String? {
        TextCleaner.stripBoxDrawingCharacters(in: text)
    }

    // MARK: - Helpers

    private func config(aggressiveness: Aggressiveness) -> TrimConfig {
        TrimConfig(
            aggressiveness: aggressiveness,
            preserveBlankLines: self.settings.preserveBlankLines,
            removeBoxDrawing: self.settings.removeBoxDrawing,
            flattenClaudeCodePrompts: self.settings.flattenClaudeCodePrompts)
    }
}
