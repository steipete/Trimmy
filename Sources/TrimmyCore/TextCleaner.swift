import Foundation

public struct TrimResult: Sendable {
    public let original: String
    public let trimmed: String
    public let wasTransformed: Bool
}

public struct TextCleaner: Sendable {
    private static let knownCommandPrefixes: [String] = [
        "sudo", "./", "~/", "apt", "brew", "git", "python", "pip", "pnpm", "npm", "yarn", "cargo",
        "bundle", "rails", "go", "make", "xcodebuild", "swift", "kubectl", "docker", "podman", "aws",
        "gcloud", "az", "ls", "cd", "cat", "echo", "env", "export", "open", "node", "java", "ruby",
        "perl", "bash", "zsh", "fish", "pwsh", "sh",
    ]

    public init() {}

    public func cleanBoxDrawingCharacters(_ text: String, enabled: Bool, chars: String) -> String? {
        guard enabled, !chars.isEmpty else { return nil }
        return Self.stripBoxDrawingCharacters(in: text, chars: chars)
    }

    public func repairWrappedURL(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        let schemeCount = (lowercased.components(separatedBy: "https://").count - 1)
            + (lowercased.components(separatedBy: "http://").count - 1)
        guard schemeCount == 1 else { return nil }
        guard lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") else { return nil }

        let collapsed = trimmed.replacingOccurrences(
            of: #"\s+"#,
            with: "",
            options: .regularExpression)

        guard collapsed != trimmed else { return nil }

        let validURLPattern = #"^https?://[A-Za-z0-9._~:/?#\\[\\]@!$&'()*+,;=%-]+$"#
        guard collapsed.range(of: validURLPattern, options: .regularExpression) != nil else { return nil }

        return collapsed
    }

    /// Quotes a filesystem path that contains spaces so it can be used directly in shell commands.
    /// Returns nil if no transformation is needed.
    public func quotePathWithSpaces(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip if empty or multi-line
        guard !trimmed.isEmpty, !trimmed.contains("\n") else { return nil }

        // Skip if already quoted
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
            || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'"))
        {
            return nil
        }

        guard let firstToken = trimmed.split(
            maxSplits: 1,
            omittingEmptySubsequences: true,
            whereSeparator: \.isWhitespace).first else { return nil }
        let firstTokenText = String(firstToken)

        // Skip URLs (even if they contain spaces)
        guard !trimmed.contains("://") else { return nil }

        // Must look like a path starting at the beginning:
        // - Absolute (/), home-relative (~/), current-dir (./), parent-dir (..)
        // - Or a relative path whose first token contains "/" (e.g., "folder/sub folder/file.txt")
        let hasExplicitPathPrefix = firstTokenText.hasPrefix("/")
            || firstTokenText.hasPrefix("~/")
            || firstTokenText.hasPrefix("./")
            || firstTokenText.hasPrefix("../")
        let looksLikeRelativePath = firstTokenText.contains("/")

        guard hasExplicitPathPrefix || looksLikeRelativePath else { return nil }

        // Must contain at least one space that would cause shell issues
        guard trimmed.contains(" ") else { return nil }

        // Skip if it looks like a command (has flags or multiple path-like segments separated by spaces)
        // e.g., "ls -la /some/path" should not be quoted as a single path
        if trimmed.range(of: #"\s-[A-Za-z]"#, options: .regularExpression) != nil {
            return nil
        }

        // Escape any existing double quotes and wrap in double quotes
        let escaped = trimmed.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    /// Removes trailing colon (and optional line:column suffix) from file paths.
    /// e.g., "/path/to/file.swift:" → "/path/to/file.swift"
    /// e.g., "/path/to/file.swift:42:" → "/path/to/file.swift"
    /// e.g., "/path/to/file.swift:42:10:" → "/path/to/file.swift"
    public func cleanPathSuffix(_ text: String, enabled: Bool) -> String? {
        guard enabled else { return nil }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Must be single line
        guard !trimmed.contains("\n") else { return nil }

        // Pattern: path followed by optional :line:col and trailing colon
        // Matches: /path/file:  or  /path/file:42:  or  /path/file:42:10:
        let pathPattern = #"^([/~][\S]*?)(:\d+)?(:\d+)?:$"#
        guard trimmed.range(of: pathPattern, options: .regularExpression) != nil else {
            return nil
        }

        // Extract just the path (without line:col suffix)
        let result = trimmed.replacingOccurrences(
            of: pathPattern,
            with: "$1",
            options: .regularExpression
        )

        return result == trimmed ? nil : result
    }

    // MARK: - Public pipeline

    public func transform(
        _ text: String,
        config: TrimConfig,
        aggressivenessOverride: Aggressiveness? = nil) -> TrimResult
    {
        var currentText = text
        var wasTransformed = false

        if let cleaned = self.cleanBoxDrawingCharacters(
            currentText,
            enabled: config.removeBoxDrawing,
            chars: config.boxDrawingChars)
        {
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

        if let cleanedPath = self.cleanPathSuffix(currentText, enabled: config.trimPathSuffix) {
            currentText = cleanedPath
            wasTransformed = true
        }

        if let quotedPath = self.quotePathWithSpaces(currentText) {
            currentText = quotedPath
            wasTransformed = true
        }

        // Format heredoc blocks (must come before flatten to preserve structure)
        if config.formatHeredoc, let heredocFormatted = self.formatHeredoc(currentText) {
            currentText = heredocFormatted
            wasTransformed = true
            // Return early - don't flatten heredoc
            return TrimResult(original: text, trimmed: currentText, wasTransformed: wasTransformed)
        }
        if let commandTransformed = self.transformIfCommand(
            currentText,
            config: config,
            aggressivenessOverride: aggressivenessOverride)
        {
            currentText = commandTransformed
            wasTransformed = true
        }

        return TrimResult(original: text, trimmed: currentText, wasTransformed: wasTransformed)
    }

    // MARK: - Command detection

    public func transformIfCommand(
        _ text: String,
        config: TrimConfig,
        aggressivenessOverride: Aggressiveness? = nil) -> String?
    {
        guard text.contains("\n") else { return nil }

        let lines = text.split(whereSeparator: { $0.isNewline })
        guard lines.count >= 2 else { return nil }
        if aggressivenessOverride != .high, lines.count > 4 {
            return nil
        }
        if aggressivenessOverride != .high, self.isLikelyList(lines) {
            return nil
        }
        if lines.count > 10 { return nil }

        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }

        let hasLineContinuation = text.contains("\\\n")
        let hasLineJoinerAtEOL = text.range(
            of: #"(?m)(\\|[|&]{1,2}|;)\s*$"#,
            options: .regularExpression) != nil
        let hasIndentedPipeline = text.range(
            of: #"(?m)^\s*[|&]{1,2}\s+\S"#,
            options: .regularExpression) != nil
        let hasExplicitLineJoin = hasLineContinuation || hasLineJoinerAtEOL || hasIndentedPipeline

        if aggressivenessOverride != .high,
           config.aggressiveness != .high,
           !hasExplicitLineJoin,
           self.commandLineCount(in: nonEmptyLines) == nonEmptyLines.count,
           nonEmptyLines.count >= 3
        {
            return nil
        }

        let aggressiveness = aggressivenessOverride ?? config.aggressiveness

        let strongCommandSignals = text.contains("\\\n")
            || text.range(of: #"[|&]{1,2}"#, options: .regularExpression) != nil
            || text.range(of: #"(^|\n)\s*\$"#, options: .regularExpression) != nil
            || text.range(of: #"[A-Za-z0-9._~-]+/[A-Za-z0-9._~-]+"#, options: .regularExpression) != nil

        let hasKnownCommandPrefix = self.containsKnownCommandPrefix(in: lines)
        if aggressiveness != .high,
           aggressivenessOverride != .high,
           !strongCommandSignals,
           !hasKnownCommandPrefix,
           !self.hasCommandPunctuation(text)
        {
            return nil
        }

        if aggressiveness != .high,
           aggressivenessOverride != .high,
           self.isLikelySourceCode(text),
           !strongCommandSignals
        {
            return nil
        }

        var score = 0
        if text.contains("\\\n") { score += 1 }
        if text.range(of: #"[|&]{1,2}"#, options: .regularExpression) != nil { score += 1 }
        if text.range(of: #"(^|\n)\s*\$"#, options: .regularExpression) != nil { score += 1 }
        if self.isSingleCommandWithIndentedContinuations(nonEmptyLines) { score += 1 }
        if lines.allSatisfy(self.isLikelyCommandLine(_:)) { score += 1 }
        if text.range(of: #"(?m)^\s*(sudo\s+)?[A-Za-z0-9./~_-]+"#, options: .regularExpression) != nil { score += 1 }
        if text.range(of: #"[A-Za-z0-9._~-]+/[A-Za-z0-9._~-]+"#, options: .regularExpression) != nil { score += 1 }

        guard score >= aggressiveness.scoreThreshold else { return nil }

        let flattened = self.flatten(text, preserveBlankLines: config.preserveBlankLines)
        return flattened == text ? nil : flattened
    }

    private func isLikelyCommandLine(_ lineSubstr: Substring) -> Bool {
        let line = lineSubstr.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return false }
        if line.hasPrefix("[[") { return true }
        if line.last == "." { return false }
        let pattern = #"^(sudo\s+)?[A-Za-z0-9./~_-]+(?:\s+|\z)"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }

    private func stripPrompt(in line: Substring) -> String? {
        let leadingWhitespace = line.prefix { $0.isWhitespace }
        let remainder = line.dropFirst(leadingWhitespace.count)

        guard let first = remainder.first, first == "#" || first == "$" else { return nil }

        let afterPrompt = remainder.dropFirst().drop { $0.isWhitespace }
        guard self.isLikelyPromptCommand(afterPrompt) else { return nil }

        return String(leadingWhitespace) + String(afterPrompt)
    }

    private func isLikelyPromptCommand(_ content: Substring) -> Bool {
        let trimmed = String(content.trimmingCharacters(in: .whitespaces))
        guard !trimmed.isEmpty else { return false }
        if let last = trimmed.last, [".", "?", "!"].contains(last) { return false }

        let hasCommandPunctuation =
            trimmed.contains(where: { "-./~$".contains($0) }) || trimmed.contains(where: \.isNumber)
        let firstToken = trimmed.split(separator: " ").first?.lowercased() ?? ""
        let startsWithKnown = Self.knownCommandPrefixes.contains(where: { firstToken.hasPrefix($0) })

        guard hasCommandPunctuation || startsWithKnown else { return false }
        return self.isLikelyCommandLine(trimmed[...])
    }

    private func isLikelySourceCode(_ text: String) -> Bool {
        let hasBraces = text.contains("{") || text.contains("}") || text.lowercased().contains("begin")
        let keywordPattern =
            #"(?m)^\s*(import|package|namespace|using|template|class|struct|enum|extension|protocol|"#
                + #"interface|func|def|fn|let|var|public|private|internal|open|protected|if|for|while)\b"#
        let hasKeywords = text.range(of: keywordPattern, options: .regularExpression) != nil
        return hasBraces && hasKeywords
    }

    private func isSingleCommandWithIndentedContinuations(_ lines: [Substring]) -> Bool {
        guard lines.count >= 2 else { return false }
        guard self.isLikelyCommandLine(lines[0]) else { return false }

        var sawIndentedLine = false

        for line in lines.dropFirst() {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard !trimmed.isEmpty else { continue }

            if line.first?.isWhitespace == true {
                sawIndentedLine = true
                continue
            }

            if trimmed.hasPrefix("|")
                || trimmed.hasPrefix("&&")
                || trimmed.hasPrefix("||")
                || trimmed.hasPrefix(";")
                || trimmed.hasPrefix(">")
                || trimmed.hasPrefix("2>")
                || trimmed.hasPrefix("<")
                || trimmed.hasPrefix("--")
                || trimmed.hasPrefix("-")
            {
                continue
            }

            return false
        }

        return sawIndentedLine
    }

    private func containsKnownCommandPrefix(in lines: [Substring]) -> Bool {
        lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard let firstToken = trimmed.split(separator: " ").first else { return false }
            let lower = firstToken.lowercased()
            return Self.knownCommandPrefixes.contains(where: { lower.hasPrefix($0) })
        }
    }

    private func hasCommandPunctuation(_ text: String) -> Bool {
        if text.contains("@") { return true }

        if text.range(
            of: #"(?m)(?:^|\s)--[A-Za-z0-9][A-Za-z0-9_-]*"#,
            options: .regularExpression) != nil
        {
            return true
        }

        if text.range(
            of: #"(?m)(?:^|\s)-[A-Za-z](?:\s|\z)"#,
            options: .regularExpression) != nil
        {
            return true
        }

        if text.range(
            of: #"(?m)\b[A-Za-z_][A-Za-z0-9_]*="#,
            options: .regularExpression) != nil
        {
            return true
        }

        if text.range(
            of: #"(?m)(?:^|\s)(?:\./|~/|/)"#,
            options: .regularExpression) != nil
        {
            return true
        }

        if text.range(
            of: #"(?m)(?:^|\s)\.[A-Za-z0-9_-]+"#,
            options: .regularExpression) != nil
        {
            return true
        }

        if text.contains("<") || text.contains(">") { return true }

        return false
    }

    private func isLikelyList(_ lines: [Substring]) -> Bool {
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard nonEmpty.count >= 2 else { return false }

        let listishCount = nonEmpty.count(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let hasSpaces = trimmed.contains(where: \.isWhitespace)
            let bulletPattern = #"^[-*•]\s+\S"#
            let numberedPattern = #"^[0-9]+[.)]\s+\S"#
            let bareTokenPattern = #"^[A-Za-z0-9]{4,}$"#

            if trimmed.range(of: bulletPattern, options: .regularExpression) != nil { return true }
            if trimmed.range(of: numberedPattern, options: .regularExpression) != nil { return true }
            if !hasSpaces,
               trimmed.range(of: bareTokenPattern, options: .regularExpression) != nil,
               trimmed.range(of: #"[./$]"#, options: .regularExpression) == nil
            {
                return true
            }
            return false
        })

        return listishCount >= (nonEmpty.count / 2 + 1)
    }

    private func commandLineCount(in lines: [Substring]) -> Int {
        lines.count(where: self.isLikelyCommandLine(_:))
    }

    private func flatten(_ text: String, preserveBlankLines: Bool) -> String {
        let placeholder = "__BLANK_SEP__"
        var result = text
        if preserveBlankLines {
            result = result.replacingOccurrences(of: "\n\\s*\n", with: placeholder, options: .regularExpression)
        }
        result = result.replacingOccurrences(
            of: #"(?<=[A-Za-z0-9._~-])-\s*\n\s*([A-Za-z0-9._~-])"#,
            with: "-$1",
            options: .regularExpression)
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

    // MARK: - Box drawing cleanup (shared)

    public static func stripBoxDrawingCharacters(
        in text: String,
        chars: String = TrimConfig.defaultBoxDrawingChars) -> String?
    {
        guard !chars.isEmpty else { return nil }

        // Build character class from the configurable chars string
        let escapedChars = NSRegularExpression.escapedPattern(for: chars)
        let charClass = "[\(escapedChars)]"

        let boxRegex = try? NSRegularExpression(pattern: charClass, options: [])
        if boxRegex?.firstMatch(in: text, options: [], range: NSRange(location: 0, length: text.utf16.count)) == nil {
            return nil
        }
        var result = text

        if result.contains("│ │") {
            result = result.replacingOccurrences(of: "│ │", with: " ")
        }

        let lines = result.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        if !nonEmptyLines.isEmpty {
            let leadingPattern = "^\\s*\(charClass)+ ?"
            let trailingPattern = " ?\(charClass)+\\s*$"
            let majorityThreshold = nonEmptyLines.count / 2 + 1

            let leadingMatches = nonEmptyLines.count(where: {
                $0.range(of: leadingPattern, options: .regularExpression) != nil
            })
            let trailingMatches = nonEmptyLines.count(where: {
                $0.range(of: trailingPattern, options: .regularExpression) != nil
            })

            let stripLeading = leadingMatches >= majorityThreshold
            let stripTrailing = trailingMatches >= majorityThreshold

            if stripLeading || stripTrailing {
                var rebuilt: [String] = []
                rebuilt.reserveCapacity(lines.count)

                for line in lines {
                    var lineStr = String(line)
                    if stripLeading {
                        lineStr = lineStr.replacingOccurrences(
                            of: leadingPattern,
                            with: "",
                            options: .regularExpression)
                    }
                    if stripTrailing {
                        lineStr = lineStr.replacingOccurrences(
                            of: trailingPattern,
                            with: "",
                            options: .regularExpression)
                    }
                    rebuilt.append(lineStr)
                }

                result = rebuilt.joined(separator: "\n")
            }
        }

        let boxAfterPipePattern = "\\|\\s*\(charClass)+\\s*"
        result = result.replacingOccurrences(
            of: boxAfterPipePattern,
            with: "| ",
            options: .regularExpression)

        let boxPathJoinPattern = "([:/])\\s*\(charClass)+\\s*([A-Za-z0-9])"
        result = result.replacingOccurrences(
            of: boxPathJoinPattern,
            with: "$1$2",
            options: .regularExpression)

        let boxMidTokenPattern = "(\\S)\\s*\(charClass)+\\s*(\\S)"
        result = result.replacingOccurrences(
            of: boxMidTokenPattern,
            with: "$1 $2",
            options: .regularExpression)

        result = result.replacingOccurrences(
            of: "\\s*\(charClass)+\\s*",
            with: " ",
            options: .regularExpression)

        let collapsed = result.replacingOccurrences(
            of: #" {2,}"#,
            with: " ",
            options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == text ? nil : trimmed
    }

    // MARK: - Heredoc formatting

    /// Formats heredoc blocks by removing common indentation and fixing the delimiter line.
    /// Returns nil if text doesn't contain a heredoc pattern.
    public func formatHeredoc(_ text: String) -> String? {
        // Pattern: << or <<- followed by optional quotes and a word
        let pattern = #"<<-?\s*['"]?([A-Za-z_][A-Za-z0-9_]*)['"]?"#
        guard text.range(of: pattern, options: .regularExpression) != nil else {
            return nil
        }

        // Extract the delimiter word (e.g., EOF)
        let nsText = text as NSString
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let nsMatch = regex.firstMatch(in: text, range: NSRange(location: 0, length: nsText.length)),
              nsMatch.numberOfRanges >= 2
        else {
            return nil
        }
        let delimiterRange = nsMatch.range(at: 1)
        let delimiter = nsText.substring(with: delimiterRange)

        // Split into lines
        let lines = text.components(separatedBy: "\n")
        guard lines.count >= 2 else { return nil }

        // Find the delimiter line (end marker)
        guard let endIndex = lines.lastIndex(where: {
            $0.trimmingCharacters(in: .whitespaces) == delimiter
        }), endIndex > 0 else {
            return nil
        }

        // Find the start line (contains << DELIMITER)
        guard let startIndex = lines.firstIndex(where: {
            $0.range(of: pattern, options: .regularExpression) != nil
        }), startIndex < endIndex else {
            return nil
        }

        // Content lines are between start and end
        let contentRange = (startIndex + 1)..<endIndex

        // Calculate minimum common indentation for content lines
        var minIndent = Int.max
        for i in contentRange {
            let line = lines[i]
            if line.trimmingCharacters(in: .whitespaces).isEmpty { continue }
            let leadingSpaces = line.prefix(while: { $0 == " " || $0 == "\t" }).count
            minIndent = min(minIndent, leadingSpaces)
        }
        if minIndent == Int.max { minIndent = 0 }

        // Also check start line for indentation
        let startLineIndent = lines[startIndex].prefix(while: { $0 == " " || $0 == "\t" }).count
        minIndent = min(minIndent, startLineIndent)

        // Apply formatting
        var result = lines

        // Remove common indentation from start line
        if startLineIndent >= minIndent {
            result[startIndex] = String(lines[startIndex].dropFirst(minIndent))
        }

        // Remove common indentation from content lines
        for i in contentRange {
            let line = lines[i]
            if line.count >= minIndent {
                result[i] = String(line.dropFirst(minIndent))
            }
        }

        // Fix end line: remove ALL leading whitespace
        result[endIndex] = lines[endIndex].trimmingCharacters(in: .init(charactersIn: " \t"))

        let formatted = result.joined(separator: "\n")
        return formatted == text ? nil : formatted
    }

    // MARK: - Prompt stripping helpers

    public func stripPromptPrefixes(_ text: String) -> String? {
        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonEmptyLines.isEmpty else { return nil }

        var strippedCount = 0
        var rebuilt: [String] = []
        rebuilt.reserveCapacity(lines.count)

        for line in lines {
            if let stripped = self.stripPrompt(in: line) {
                strippedCount += 1
                rebuilt.append(stripped)
            } else {
                rebuilt.append(String(line))
            }
        }

        let majorityThreshold = nonEmptyLines.count / 2 + 1
        let shouldStrip = nonEmptyLines.count == 1 ? strippedCount == 1 : strippedCount >= majorityThreshold
        guard shouldStrip else { return nil }

        let result = rebuilt.joined(separator: "\n")
        return result == text ? nil : result
    }
}
