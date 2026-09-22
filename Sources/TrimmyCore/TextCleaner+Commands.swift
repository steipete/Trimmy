import Foundation

extension TextCleaner {
    private static let knownCommandPrefixes: [String] = [
        "sudo", "./", "~/", "apt", "brew", "git", "python", "pip", "pnpm", "npm", "yarn", "cargo",
        "bundle", "rails", "go", "make", "xcodebuild", "swift", "kubectl", "docker", "podman", "aws",
        "gcloud", "az", "ls", "cd", "cat", "echo", "env", "export", "open", "node", "java", "ruby",
        "perl", "bash", "zsh", "fish", "pwsh", "sh",
    ]

    /// Removes shared leading indentation from prose paragraphs while avoiding code, lists, and commands.
    public func dedentParagraphIndent(_ text: String) -> String? {
        guard text.contains(where: \.isNewline) else { return nil }

        let lines = text.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline).map(String.init)
        let nonEmptyIndices = lines.indices.filter {
            !lines[$0].trimmingCharacters(in: .whitespaces).isEmpty
        }
        guard nonEmptyIndices.count >= 2 else { return nil }

        let nonEmptyLines = nonEmptyIndices.map { lines[$0][...] }
        guard !self.isLikelyList(nonEmptyLines),
              !self.isLikelySourceCode(text),
              !self.isLikelyStructuredData(nonEmptyLines),
              !Self.containsYAMLBlockScalar(text),
              !self.hasCommandPunctuation(text)
        else {
            return nil
        }

        let indentedProseLines = nonEmptyIndices.compactMap { index -> Int? in
            let line = lines[index]
            let indent = line.prefix(while: \.isWhitespace).count
            guard indent > 0 else { return nil }
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard self.isLikelyProseLine(trimmed) else { return nil }
            return indent
        }

        let requiredIndentedLines = max(2, nonEmptyIndices.count / 2 + 1)
        guard indentedProseLines.count >= requiredIndentedLines,
              let commonIndent = indentedProseLines.min(),
              commonIndent > 0
        else {
            return nil
        }

        let dedented = lines.map { line -> String in
            let indent = line.prefix(while: \.isWhitespace).count
            guard indent >= commonIndent else { return line }
            return String(line.dropFirst(commonIndent))
        }.joined(separator: "\n")

        return dedented == text ? nil : dedented
    }

    public static func containsYAMLBlockScalar(_ text: String) -> Bool {
        // Preserve raw scalar contents before cleanup can strip meaningful indentation or glyphs.
        let prefix = #"(?:---\s+)?(?:(?:[^#\s][^\r\n]*)?:\s*)?(?:-\s+)*"#
        let properties = #"(?:(?:!\S*|&\S+)\s+)*"#
        let scalar = #"[|>](?:[1-9][+-]?|[+-][1-9]?)?(?:\s+#.*)?$"#
        return text.split(whereSeparator: \.isNewline).contains { line in
            line.trimmingCharacters(in: .whitespaces)
                .range(of: "^" + prefix + properties + scalar, options: .regularExpression) != nil
        }
    }

    // MARK: - Command detection

    public func transformIfCommand(
        _ text: String,
        config: TrimConfig,
        aggressivenessOverride: Aggressiveness? = nil) -> String?
    {
        let text = text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
        guard text.contains("\n") else { return nil }

        let lines = text.split(whereSeparator: { $0.isNewline })
        guard lines.count >= 2 else { return nil }
        if aggressivenessOverride != .high, lines.count > 4 {
            return nil
        }
        if aggressivenessOverride != .high, self.isLikelyList(lines) {
            return nil
        }
        if lines.count > 10 {
            return nil
        }

        let nonEmptyLines = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        let aggressiveness = aggressivenessOverride ?? config.aggressiveness
        if aggressiveness != .high, Self.containsYAMLBlockScalar(text) {
            return nil
        }

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
           nonEmptyLines.allSatisfy(self.isLikelyCommandLine(_:)),
           nonEmptyLines.count >= 3
        {
            return nil
        }

        let hasPipeOrJoiner = text.range(of: #"[|&]{1,2}"#, options: .regularExpression) != nil
        let hasPrompt = text.range(of: #"(^|\n)\s*\$"#, options: .regularExpression) != nil
        let hasPath = text.range(of: #"[A-Za-z0-9._~-]+/[A-Za-z0-9._~-]+"#, options: .regularExpression) != nil
        let strongCommandSignals = hasLineContinuation || hasPipeOrJoiner || hasPrompt || hasPath

        let hasKnownCommandPrefix = self.containsKnownCommandPrefix(in: lines)
        if aggressiveness != .high,
           !strongCommandSignals,
           !hasKnownCommandPrefix,
           !self.hasCommandPunctuation(text)
        {
            return nil
        }

        if aggressiveness != .high,
           self.isLikelySourceCode(text),
           !strongCommandSignals
        {
            return nil
        }

        var score = 0
        if hasLineContinuation {
            score += 1
        }
        if hasPipeOrJoiner {
            score += 1
        }
        if hasPrompt {
            score += 1
        }
        if self.isSingleCommandWithIndentedContinuations(nonEmptyLines) {
            score += 1
        }
        if lines.allSatisfy(self.isLikelyCommandLine(_:)) {
            score += 1
        }
        if text.range(of: #"(?m)^\s*(sudo\s+)?[A-Za-z0-9./~_-]+"#, options: .regularExpression) != nil {
            score += 1
        }
        if hasPath {
            score += 1
        }

        guard score >= aggressiveness.scoreThreshold else { return nil }

        let flattened = self.flatten(text, preserveBlankLines: config.preserveBlankLines)
        return flattened == text ? nil : flattened
    }

    private func isLikelyCommandLine(_ lineSubstr: Substring) -> Bool {
        let line = lineSubstr.trimmingCharacters(in: .whitespaces)
        guard !line.isEmpty else { return false }
        if line.hasPrefix("[[") {
            return true
        }
        if line.last == "." {
            return false
        }
        let pattern = #"^(sudo\s+)?[A-Za-z0-9./~_-]+(?:\s+|\z)"#
        return line.range(of: pattern, options: .regularExpression) != nil
    }

    private func stripPrompt(in line: Substring) -> String? {
        let leadingWhitespace = line.prefix { $0.isWhitespace }
        let remainder = line.dropFirst(leadingWhitespace.count)

        guard let first = remainder.first, first == "#" || first == "$" else { return nil }

        let afterMarker = remainder.dropFirst()
        guard afterMarker.first?.isWhitespace == true else { return nil }
        let afterPrompt = afterMarker.drop { $0.isWhitespace }
        guard self.isLikelyPromptCommand(afterPrompt, marker: first) else { return nil }

        return String(leadingWhitespace) + String(afterPrompt)
    }

    private func isLikelyPromptCommand(_ content: Substring, marker: Character) -> Bool {
        let trimmed = String(content.trimmingCharacters(in: .whitespaces))
        guard !trimmed.isEmpty else { return false }
        if let last = trimmed.last, [".", "?", "!"].contains(last) {
            return false
        }

        let hasCommandPunctuation =
            trimmed.contains(where: { "-./~$".contains($0) }) || trimmed.contains(where: \.isNumber)
        let firstToken = trimmed.split(whereSeparator: \.isWhitespace).first?.lowercased() ?? ""
        // A hash can introduce a Markdown heading; a dollar prompt has no such ambiguity.
        let startsWithKnown = Self.knownCommandPrefixes.contains {
            firstToken == $0 || (marker == "$" && firstToken.hasPrefix($0))
        }

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
        if text.contains("@") {
            return true
        }

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

        if text.contains("<") || text.contains(">") {
            return true
        }

        return false
    }

    private func isLikelyProseLine(_ line: String) -> Bool {
        guard let first = line.first, first.isLetter || "\"'(".contains(first) else { return false }
        if line.range(of: #"^[-*•]|^[0-9]+[.)]\s|^(?:\$|#|>|[|&;{}])"#, options: .regularExpression) != nil {
            return false
        }
        if line.range(of: #"^["'][^"']+["']\s*:"#, options: .regularExpression) != nil {
            return false
        }
        if line.range(
            of: #"^(?:sudo|git|npm|pnpm|yarn|swift|xcodebuild|docker|kubectl|cd|ls|cat|echo|make)\b"#,
            options: [.regularExpression, .caseInsensitive]) != nil
        {
            return false
        }
        return line.contains(where: \.isWhitespace) || line.range(of: #"[,.!?;:]"#, options: .regularExpression) != nil
    }

    private func isLikelyStructuredData(_ lines: [Substring]) -> Bool {
        lines.contains { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if ["{", "}", "[", "]"].contains(trimmed) {
                return true
            }
            return trimmed.range(of: #"^["'][^"']+["']\s*:"#, options: .regularExpression) != nil
        }
    }

    private func isLikelyList(_ lines: [Substring]) -> Bool {
        let nonEmpty = lines.filter { !$0.trimmingCharacters(in: .whitespaces).isEmpty }
        guard nonEmpty.count >= 2 else { return false }

        let listishCount = nonEmpty.count(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let bulletPattern = #"^[-*•]\s+\S"#
            let numberedPattern = #"^[0-9]+[.)]\s+\S"#
            let bareTokenPattern = #"^[A-Za-z0-9]{4,}$"#

            if trimmed.range(of: bulletPattern, options: .regularExpression) != nil {
                return true
            }
            if trimmed.range(of: numberedPattern, options: .regularExpression) != nil {
                return true
            }
            return trimmed.range(of: bareTokenPattern, options: .regularExpression) != nil
        })

        return listishCount >= (nonEmpty.count / 2 + 1)
    }

    private func flatten(_ text: String, preserveBlankLines: Bool) -> String {
        if preserveBlankLines {
            return text.split(separator: /\n\s*\n/, omittingEmptySubsequences: false)
                .map { self.flatten(String($0), preserveBlankLines: false) }
                .joined(separator: "\n\n")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        var result = text
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
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
