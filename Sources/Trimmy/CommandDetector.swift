import Foundation
import TrimmyCore

@MainActor
struct CommandDetector {
    let settings: AppSettings
    private let cleaner = TextCleaner()

    func cleanBoxDrawingCharacters(_ text: String) -> String? {
        self.cleaner.cleanBoxDrawingCharacters(text, enabled: self.settings.removeBoxDrawing)
    }

    func stripClaudeCodeDecoration(_ text: String) -> String? {
        self.cleaner.stripClaudeCodeDecoration(text, enabled: self.settings.flattenClaudeCodePrompts)
    }

    func stripPromptPrefixes(_ text: String) -> String? {
        self.cleaner.stripPromptPrefixes(text)
    }

    func repairWrappedURL(_ text: String) -> String? {
        self.cleaner.repairWrappedURL(text)
    }

    func quotePathWithSpaces(_ text: String) -> String? {
        self.cleaner.quotePathWithSpaces(text)
    }

    func transformIfCommand(_ text: String, aggressivenessOverride: Aggressiveness? = nil) -> String? {
        let baseAggressiveness = self.settings.generalAggressiveness.coreAggressiveness
        guard let aggressiveness = aggressivenessOverride ?? baseAggressiveness else { return nil }
        return self.transformIfCommand(
            text,
            aggressiveness: aggressiveness,
            aggressivenessOverride: aggressivenessOverride)
    }

    func transformIfCommand(
        _ text: String,
        aggressiveness: Aggressiveness,
        aggressivenessOverride: Aggressiveness? = nil) -> String?
    {
        self.cleaner.transformIfCommand(
            text,
            config: self.config(aggressiveness: aggressiveness),
            aggressivenessOverride: aggressivenessOverride)
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
