import Foundation
import TrimmyCore

@MainActor
struct CommandDetector {
    let settings: AppSettings
    private let cleaner = TextCleaner()

    func cleanBoxDrawingCharacters(_ text: String) -> String? {
        self.cleaner.cleanBoxDrawingCharacters(text, enabled: self.settings.removeBoxDrawing)
    }

    func stripPromptPrefixes(_ text: String) -> String? {
        self.cleaner.stripPromptPrefixes(text)
    }

    func repairWrappedURL(_ text: String) -> String? {
        self.cleaner.repairWrappedURL(text)
    }

    func transformIfCommand(_ text: String, aggressivenessOverride: Aggressiveness? = nil) -> String? {
        self.cleaner.transformIfCommand(text, config: self.config(), aggressivenessOverride: aggressivenessOverride)
    }

    nonisolated static func stripBoxDrawingCharacters(in text: String) -> String? {
        TextCleaner.stripBoxDrawingCharacters(in: text)
    }

    // MARK: - Helpers

    private func config() -> TrimConfig {
        TrimConfig(
            aggressiveness: self.settings.aggressiveness,
            preserveBlankLines: self.settings.preserveBlankLines,
            removeBoxDrawing: self.settings.removeBoxDrawing)
    }
}
