import Foundation

extension TextCleaner {
    private static let boxDrawingCharacterClass = "[│┃╎╏┆┇┊┋╽╿￨｜]"

    public func cleanBoxDrawingCharacters(_ text: String, enabled: Bool) -> String? {
        guard enabled else { return nil }
        return Self.stripBoxDrawingCharacters(in: text)
    }

    // MARK: - Box drawing cleanup (shared)

    public static func stripBoxDrawingCharacters(in text: String) -> String? {
        guard text.range(of: self.boxDrawingCharacterClass, options: .regularExpression) != nil else {
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
}
