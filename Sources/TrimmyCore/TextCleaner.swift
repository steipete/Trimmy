import Foundation

public struct TrimResult: Sendable {
    public let original: String
    public let trimmed: String
    public let wasTransformed: Bool
}

public struct TextCleaner: Sendable {
    public init() {}

    public func transform(
        _ text: String,
        config: TrimConfig,
        aggressivenessOverride: Aggressiveness? = nil) -> TrimResult
    {
        self.transform(
            text,
            config: config,
            aggressivenessOverride: aggressivenessOverride,
            commandFlatteningEnabled: true,
            paragraphDedentEnabled: true)
    }

    public func transform(
        _ text: String,
        config: TrimConfig,
        aggressivenessOverride: Aggressiveness? = nil,
        commandFlatteningEnabled: Bool,
        paragraphDedentEnabled: Bool) -> TrimResult
    {
        if (aggressivenessOverride ?? config.aggressiveness) != .high, Self.containsYAMLBlockScalar(text) {
            return TrimResult(original: text, trimmed: text, wasTransformed: false)
        }
        var currentText = text
        var wasTransformed = false

        if let cleaned = self.cleanBoxDrawingCharacters(currentText, enabled: config.removeBoxDrawing) {
            currentText = cleaned
            wasTransformed = true
        }

        if let cleaned = self.stripClaudeCodeDecoration(currentText, enabled: config.flattenClaudeCodePrompts) {
            currentText = cleaned
            wasTransformed = true
        }

        if let promptStripped = self.stripPromptPrefixes(currentText) {
            currentText = promptStripped
            wasTransformed = true
        }

        if let repairedURL = self.repairWrappedURL(currentText) {
            currentText = repairedURL
            wasTransformed = true
        }

        if let quotedPath = self.quotePathWithSpaces(currentText) {
            currentText = quotedPath
            wasTransformed = true
        }

        if commandFlatteningEnabled, let commandTransformed = self.transformIfCommand(
            currentText,
            config: config,
            aggressivenessOverride: aggressivenessOverride)
        {
            currentText = commandTransformed
            wasTransformed = true
        }

        if paragraphDedentEnabled, let dedentedParagraph = self.dedentParagraphIndent(currentText) {
            currentText = dedentedParagraph
            wasTransformed = true
        }

        return TrimResult(original: text, trimmed: currentText, wasTransformed: wasTransformed)
    }
}
