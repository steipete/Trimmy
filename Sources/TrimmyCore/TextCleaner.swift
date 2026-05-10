import Foundation

public struct TrimResult: Sendable {
    public let original: String
    public let trimmed: String
    public let wasTransformed: Bool
}

public struct TextCleaner: Sendable {
    private static let boxDrawingCharacterClass = "[│┃╎╏┆┇┊┋╽╿￨｜]"
    private static let knownCommandPrefixes: [String] = [
        "sudo", "./", "~/", "apt", "brew", "git", "python", "pip", "pnpm", "npm", "yarn", "cargo",
        "bundle", "rails", "go", "make", "xcodebuild", "swift", "kubectl", "docker", "podman", "aws",
        "gcloud", "az", "ls", "cd", "cat", "echo", "env", "export", "open", "node", "java", "ruby",
        "perl", "bash", "zsh", "fish", "pwsh", "sh",
    ]

    public init() {}

    public func cleanBoxDrawingCharacters(_ text: String, enabled: Bool) -> String? {
        guard enabled else { return nil }
        return Self.stripBoxDrawingCharacters(in: text)
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

        // Skip slash commands (e.g., "/skill:cmd args")
        if trimmed.range(of: #"^/[A-Za-z0-9_-]+(:[A-Za-z0-9_-]+)?\s"#, options: .regularExpression) != nil {
            return nil
        }

        // Skip if it looks like a command (has flags or multiple path-like segments separated by spaces)
        // e.g., "ls -la /some/path" should not be quoted as a single path
        if trimmed.range(of: #"\s--?[A-Za-z]"#, options: .regularExpression) != nil {
            return nil
        }

        // Escape any existing double quotes and wrap in double quotes
        let escaped = trimmed.replacingOccurrences(of: "\"", with: "\\\"")
        return "\"\(escaped)\""
    }

    // MARK: - Public pipeline

    public func transform(
        _ text: String,
        config: TrimConfig,
        aggressivenessOverride: Aggressiveness? = nil) -> TrimResult
    {
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
            of: #"(?<!\n)([A-Z0-9_.-])\s*\n\s*(?!-)([A-Z0-9_.-])(?!\n)"#,
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

    public static func stripBoxDrawingCharacters(in text: String) -> String? {
        let boxRegex = try? NSRegularExpression(pattern: self.boxDrawingCharacterClass, options: [])
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
            let leadingPattern =
                #"^\s*\#(boxDrawingCharacterClass)+ ?"#
            let trailingPattern =
                #" ?\#(boxDrawingCharacterClass)+\s*$"#
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

        let boxAfterPipePattern = #"\|\s*\#(boxDrawingCharacterClass)+\s*"#
        result = result.replacingOccurrences(
            of: boxAfterPipePattern,
            with: "| ",
            options: .regularExpression)

        let boxPathJoinPattern = #"([:/])\s*\#(boxDrawingCharacterClass)+\s*([A-Za-z0-9])"#
        result = result.replacingOccurrences(
            of: boxPathJoinPattern,
            with: "$1$2",
            options: .regularExpression)

        let boxMidTokenPattern = #"(\S)\s*\#(boxDrawingCharacterClass)+\s*(\S)"#
        result = result.replacingOccurrences(
            of: boxMidTokenPattern,
            with: "$1 $2",
            options: .regularExpression)

        result = result.replacingOccurrences(
            of: #"\s*\#(self.boxDrawingCharacterClass)+\s*"#,
            with: " ",
            options: .regularExpression)

        let collapsed = result.replacingOccurrences(
            of: #" {2,}"#,
            with: " ",
            options: .regularExpression)
        let trimmed = collapsed.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed == text ? nil : trimmed
    }

    // MARK: - Claude Code prompt stripping

    public func stripClaudeCodeDecoration(_ text: String, enabled: Bool) -> String? {
        guard enabled else { return nil }

        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard !nonEmptyLines.isEmpty else { return nil }

        let firstNonEmpty = nonEmptyLines[0].trimmingCharacters(in: .whitespaces)

        // A. Full decoration: first line starts with ❯, a horizontal rule line follows
        if firstNonEmpty.hasPrefix("\u{276F}") {
            let ruleIndex = lines.firstIndex { line in
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                let dashes = trimmed.filter { $0 == "\u{2500}" || $0 == "\u{2501}" }
                return dashes.count >= 10
            }
            if let ruleIndex {
                // Take content after the rule, flatten
                let contentLines = lines[(ruleIndex + 1)...]
                let content = contentLines.map { String($0) }
                let nonEmptyContent = content.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
                guard !nonEmptyContent.isEmpty else { return nil }
                let result = self.flattenWrappedLines(nonEmptyContent)
                return result == text ? nil : result
            }
            // B. ❯ prefix only: first line starts with ❯, no rule
            let stripped = firstNonEmpty.drop { $0 == "\u{276F}" || $0.isWhitespace }
            if nonEmptyLines.count == 1 {
                let result = String(stripped)
                return result == text ? nil : result
            }
            // Multi-line with ❯ prefix, no rule → strip ❯ from first line, flatten all
            var allLines = nonEmptyLines.map { String($0) }
            allLines[0] = String(stripped)
            let result = self.flattenWrappedLines(allLines)
            return result == text ? nil : result
        }

        // C. Slash command: first line matches /command or /skill:command pattern, multi-line
        if firstNonEmpty.range(
            of: #"^/[A-Za-z0-9_-]+(:[A-Za-z0-9_-]+)?($|[\s"])"#,
            options: .regularExpression) != nil,
            nonEmptyLines.count >= 2
        {
            let result = self.flattenWrappedLines(nonEmptyLines.map { String($0) })
            return result == text ? nil : result
        }

        // E. Outer-quoted slash command: terminal wraps the command in quotes and escapes inner quotes
        //    e.g. "/ralph-loop:ralph-loop \"args here\"" → /ralph-loop:ralph-loop "args here"
        let trimmedText = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedText.hasPrefix("\"/"), trimmedText.hasSuffix("\""), trimmedText.contains("\\\"") {
            let unquoted = String(trimmedText.dropFirst().dropLast())
            let unescaped = unquoted.replacingOccurrences(of: "\\\"", with: "\"")
            return unescaped == text ? nil : unescaped
        }

        return nil
    }

    private func flattenWrappedLines(_ lines: [String]) -> String {
        lines
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .joined(separator: " ")
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
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
