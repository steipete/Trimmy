import Foundation
import TrimmyCore

struct MarkdownReformatter {
    private struct Analysis {
        let headingCount: Int
        let listCount: Int
    }

    private struct FenceState {
        let character: Character
        let count: Int
    }

    private struct ListMatch {
        let indent: String
        let indentCount: Int
        let marker: String
        let content: String
    }

    private struct ListItem {
        let indent: String
        let indentCount: Int
        let marker: String
        var parts: [String]
    }

    static func isLikelyMarkdown(_ text: String) -> Bool {
        let analysis = self.analyze(text)
        if analysis.listCount >= 2 {
            return true
        }
        if analysis.headingCount >= 2 {
            return true
        }
        if analysis.headingCount >= 1, analysis.listCount >= 1 {
            return true
        }
        return false
    }

    static func isLikelyReflowable(_ text: String) -> Bool {
        !self.hasLikelyStructuredSyntax(text)
            && (self.isLikelyMarkdown(text) || self.hasLikelyHardWrappedParagraph(text))
    }

    static func reformat(_ text: String, trimLeadingBlankLines: Bool = false) -> String {
        let normalized = self.normalizeLineEndings(text)
        let lines = normalized.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var output: [String] = []
        var paragraphParts: [String] = []
        var listItem: ListItem?
        var fence: FenceState?

        func flushParagraph() {
            guard !paragraphParts.isEmpty else { return }
            output.append(self.joinParts(paragraphParts))
            paragraphParts.removeAll(keepingCapacity: true)
        }

        func flushListItem() {
            guard let item = listItem else { return }
            let merged = self.joinParts(item.parts)
            output.append("\(item.indent)\(item.marker) \(merged)")
            listItem = nil
        }

        for lineSlice in lines {
            let line = String(lineSlice)
            if let fenceState = fence {
                output.append(line)
                if self.isFenceClose(line, fence: fenceState) {
                    fence = nil
                }
                continue
            }

            if let fenceState = self.fenceOpen(line) {
                flushParagraph()
                flushListItem()
                output.append(line)
                fence = fenceState
                continue
            }

            if line.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty {
                flushParagraph()
                flushListItem()
                output.append("")
                continue
            }

            if self.isHeadingLine(line) {
                flushParagraph()
                flushListItem()
                output.append(self.trimTrailingWhitespace(line))
                continue
            }

            if let match = self.listMatch(for: line) {
                flushParagraph()
                flushListItem()
                listItem = ListItem(
                    indent: match.indent,
                    indentCount: match.indentCount,
                    marker: match.marker,
                    parts: [match.content])
                continue
            }

            if var item = listItem {
                let (_, indentCount) = self.leadingWhitespace(in: line)
                if indentCount > item.indentCount {
                    item.parts.append(line.trimmingCharacters(in: CharacterSet.whitespaces))
                    listItem = item
                } else {
                    flushListItem()
                    paragraphParts.append(line.trimmingCharacters(in: CharacterSet.whitespaces))
                }
                continue
            }

            paragraphParts.append(line.trimmingCharacters(in: CharacterSet.whitespaces))
        }

        flushListItem()
        flushParagraph()

        if trimLeadingBlankLines {
            while output.first?.isEmpty == true {
                output.removeFirst()
            }
        }

        return output.joined(separator: "\n")
    }

    // MARK: - Analysis

    private static func analyze(_ text: String) -> Analysis {
        let normalized = self.normalizeLineEndings(text)
        let lines = normalized.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var headingCount = 0
        var listCount = 0
        var fence: FenceState?

        for lineSlice in lines {
            let line = String(lineSlice)
            if let fenceState = fence {
                if self.isFenceClose(line, fence: fenceState) {
                    fence = nil
                }
                continue
            }
            if let fenceState = self.fenceOpen(line) {
                fence = fenceState
                continue
            }
            if self.isHeadingLine(line) {
                headingCount += 1
                continue
            }
            if self.listMatch(for: line) != nil {
                listCount += 1
            }
        }

        return Analysis(headingCount: headingCount, listCount: listCount)
    }

    private static func hasLikelyHardWrappedParagraph(_ text: String) -> Bool {
        let normalized = self.normalizeLineEndings(text)
        let lines = normalized.split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
        var paragraphLines: [String] = []
        var fence: FenceState?

        func paragraphLooksHardWrapped() -> Bool {
            guard paragraphLines.count >= 2 else { return false }
            let wrappedLines = paragraphLines.dropLast()
            guard wrappedLines.allSatisfy({ $0.split(whereSeparator: \.isWhitespace).count >= 4 }) else {
                return false
            }
            return wrappedLines.contains { line in
                line.trimmingCharacters(in: CharacterSet.whitespaces).count >= 40
            }
        }

        for lineSlice in lines {
            let line = String(lineSlice)
            if let fenceState = fence {
                if self.isFenceClose(line, fence: fenceState) {
                    fence = nil
                }
                continue
            }

            if let fenceState = self.fenceOpen(line) {
                if paragraphLooksHardWrapped() {
                    return true
                }
                paragraphLines.removeAll(keepingCapacity: true)
                fence = fenceState
                continue
            }

            if line.trimmingCharacters(in: CharacterSet.whitespaces).isEmpty
                || self.isHeadingLine(line)
                || self.listMatch(for: line) != nil
            {
                if paragraphLooksHardWrapped() {
                    return true
                }
                paragraphLines.removeAll(keepingCapacity: true)
                continue
            }

            paragraphLines.append(line)
        }

        return paragraphLooksHardWrapped()
    }

    private static func hasLikelyStructuredSyntax(_ text: String) -> Bool {
        let unfenced = self.unfencedLines(text)
        if self.containsIndentedCode(in: unfenced) {
            return true
        }
        if zip(unfenced, unfenced.dropFirst()).contains(where: { line, next in
            !next.trimmingCharacters(in: .whitespaces).isEmpty
                && line.trimmingCharacters(in: .whitespaces).range(
                    of: #"(?:[A-Za-z][A-Za-z0-9+.-]*://|\]\()[^\s]+$"#,
                    options: .regularExpression) != nil
        }) {
            return true
        }
        let lines = unfenced
            .map { $0.trimmingCharacters(in: CharacterSet.whitespaces) }
            .filter { !$0.isEmpty }
        if TextCleaner.containsYAMLBlockScalar(lines.joined(separator: "\n"))
            || lines.contains(where: self.isSourceOrConfigurationLine)
            || self.containsDelimitedRecords(lines)
        {
            return true
        }

        let structuredLineCount = lines.count(where: self.isLikelyStructuredLine)
        return structuredLineCount >= 2
    }

    private static func containsDelimitedRecords(_ lines: [String]) -> Bool {
        for separator: Character in [",", "\t"] {
            var fields: [String] = []
            var field = ""
            var quoted = false
            var multiline = false
            var previousCount = 0
            var previousExplicit = false
            var previousHeader = false
            for character in lines.joined(separator: "\n") + "\n" {
                if character == "\"" {
                    quoted.toggle()
                }
                if character == "\n", quoted {
                    multiline = true
                }
                if character == separator, !quoted {
                    fields.append(field)
                    field = ""
                    continue
                }
                guard character == "\n", !quoted else {
                    field.append(character)
                    continue
                }
                fields.append(field)
                let trimmed = fields.map { $0.trimmingCharacters(in: .whitespaces) }
                let shortFieldCount = trimmed.count { field in
                    !field.isEmpty && field.split(whereSeparator: \.isWhitespace).count < 4
                }
                let explicit = separator == "\t"
                    || shortFieldCount > 0
                    || trimmed.contains { $0.hasPrefix("\"") && $0.hasSuffix("\"") }
                    || fields.dropFirst().contains { $0.first?.isWhitespace == false }
                let header = shortFieldCount == trimmed.count
                if fields.count > 1,
                   multiline && explicit
                   || fields.count == previousCount && (explicit && previousExplicit || header || previousHeader)
                {
                    return true
                }
                previousCount = fields.count
                previousExplicit = explicit
                previousHeader = header
                fields.removeAll(keepingCapacity: true)
                field = ""
                multiline = false
            }
            if quoted, multiline, !fields.isEmpty {
                return true
            }
        }
        return false
    }

    private static func unfencedLines(_ text: String) -> [String] {
        var fence: FenceState?
        return self.normalizeLineEndings(text).components(separatedBy: "\n").map { line in
            if let current = fence {
                if self.isFenceClose(line, fence: current) {
                    fence = nil
                }
                return ""
            }
            if let opened = self.fenceOpen(line) {
                fence = opened
                return ""
            }
            return line
        }
    }

    static func containsIndentedCode(_ text: String) -> Bool {
        self.containsIndentedCode(in: self.unfencedLines(text))
    }

    private static func containsIndentedCode(in lines: [String]) -> Bool {
        var startsBlock = true
        var listContentIndent: Int?
        for line in lines {
            if line.trimmingCharacters(in: .whitespaces).isEmpty {
                startsBlock = true
                continue
            }
            let (_, indent) = self.leadingWhitespace(in: line)
            if indent < 4, self.isHeadingLine(line) {
                startsBlock = true
                listContentIndent = nil
                continue
            }
            if let list = self.listMatch(for: line) {
                listContentIndent = list.indentCount + list.marker.count + 1
                startsBlock = false
                continue
            }
            if let contentIndent = listContentIndent, indent < contentIndent {
                listContentIndent = nil
            }
            if startsBlock, indent >= (listContentIndent ?? 0) + 4 || line.hasPrefix("\t") {
                return true
            }
            startsBlock = false
        }
        return false
    }

    private static func isSourceOrConfigurationLine(_ line: String) -> Bool {
        let patterns = [
            #"^[rRuUfFbB#]*(?:\"{3}|'{3})"#,
            #"^\|?\s*:?-+:?\s*(?:\|\s*:?-+:?\s*)+\|?$"#,
            #"^>|^[-=]{3,}$"#,
            #"^[│┃╭╮╰╯┌┐└┘├┤┬┴┼─━]"#,
            #"^(?://|--|/\*|\*/|[{}\[\]])"#,
            #"^(?:import|from|package|namespace|using|class|struct|enum|extension|protocol|interface|"#
                + #"func|function|def|fn|let|var|const|public|private|internal|protected)\s"#,
            #"^[A-Za-z_][A-Za-z0-9_.]*\s*\("#,
            #"^(?:if|for|while|with|try|except|elif|else)\b.*[:{]$"#,
            #"^(?:sudo|git|npm|pnpm|yarn|swift|docker|kubectl|cd|ls|cat|echo|printf|curl|wget|export)\s"#,
            #"^(?:\$\s|--[A-Za-z])|(?:\\|\||&&)\s*$"#,
            #"[;{}]$"#,
            #"^(?:\"[^\"]+\"|'[^']+'|[\p{L}\p{N}_][\p{L}\p{N}_. -]*)\s*[:=]"#,
        ]
        return patterns.contains { line.range(of: $0, options: .regularExpression) != nil }
    }

    private static func isLikelyStructuredLine(_ line: String) -> Bool {
        let patterns = [
            #"^(?:-\s+)?(?:\"[^\"]+\"|'[^']+'|[A-Za-z_][A-Za-z0-9_.-]*)\s*:"#,
            #"^[A-Za-z_][A-Za-z0-9_.-]*\s*=\s*\S+"#,
            #"^\[[^\]]+\]\s*$"#,
            #"^<[/!?]?[A-Za-z][^>]*>"#,
        ]
        return patterns.contains { pattern in
            line.range(of: pattern, options: .regularExpression) != nil
        }
    }

    private static func normalizeLineEndings(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n")
    }

    // MARK: - Markdown detection helpers

    private static func fenceOpen(_ line: String) -> FenceState? {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        guard let first = trimmed.first, first == "`" || first == "~" else { return nil }
        let count = trimmed.prefix(while: { $0 == first }).count
        guard count >= 3 else { return nil }
        return FenceState(character: first, count: count)
    }

    private static func isFenceClose(_ line: String, fence: FenceState) -> Bool {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        guard trimmed.first == fence.character else { return false }
        let count = trimmed.prefix(while: { $0 == fence.character }).count
        return count >= fence.count && trimmed.dropFirst(count).allSatisfy { $0 == " " || $0 == "\t" }
    }

    private static func isHeadingLine(_ line: String) -> Bool {
        let trimmed = line.drop(while: { $0 == " " || $0 == "\t" })
        guard trimmed.first == "#" else { return false }
        let hashes = trimmed.prefix(while: { $0 == "#" })
        guard hashes.count >= 1, hashes.count <= 6 else { return false }
        guard hashes.endIndex < trimmed.endIndex else { return false }
        let next = trimmed[hashes.endIndex]
        return next == " " || next == "\t"
    }

    private static func listMatch(for line: String) -> ListMatch? {
        let (indent, indentCount) = self.leadingWhitespace(in: line)
        let rest = line.dropFirst(indent.count)
        guard let first = rest.first else { return nil }
        if first == "-" || first == "*" || first == "+" || first == "•" {
            let markerEnd = rest.index(after: rest.startIndex)
            guard markerEnd < rest.endIndex, rest[markerEnd].isWhitespace else { return nil }
            let content = rest[markerEnd...].trimmingCharacters(in: CharacterSet.whitespaces)
            guard !content.isEmpty else { return nil }
            return ListMatch(indent: indent, indentCount: indentCount, marker: String(first), content: content)
        }

        var index = rest.startIndex
        var digits = ""
        while index < rest.endIndex, rest[index].isASCII, rest[index].isNumber {
            digits.append(rest[index])
            index = rest.index(after: index)
        }
        guard !digits.isEmpty, digits.count <= 9, index < rest.endIndex else { return nil }
        let markerChar = rest[index]
        guard markerChar == "." || markerChar == ")" else { return nil }
        var contentStart = rest.index(after: index)
        guard contentStart < rest.endIndex, rest[contentStart] == " " || rest[contentStart] == "\t" else { return nil }
        while contentStart < rest.endIndex, rest[contentStart].isWhitespace {
            contentStart = rest.index(after: contentStart)
        }
        guard contentStart < rest.endIndex else { return nil }
        let content = rest[contentStart...].trimmingCharacters(in: CharacterSet.whitespaces)
        guard !content.isEmpty else { return nil }
        return ListMatch(
            indent: indent,
            indentCount: indentCount,
            marker: digits + String(markerChar),
            content: content)
    }

    // MARK: - Text helpers

    private static func leadingWhitespace(in line: String) -> (String, Int) {
        let prefix = line.prefix(while: { $0 == " " || $0 == "\t" })
        return (String(prefix), prefix.count)
    }

    private static func trimTrailingWhitespace(_ text: String) -> String {
        text.replacingOccurrences(of: #"[ \t]+$"#, with: "", options: .regularExpression)
    }

    private static func joinParts(_ parts: [String]) -> String {
        var result = ""
        for part in parts {
            let trimmed = part.trimmingCharacters(in: CharacterSet.whitespaces)
            guard !trimmed.isEmpty else { continue }
            if result.isEmpty {
                result = trimmed
                continue
            }
            let attachedHyphen = self.hyphenIsAttachedToPreviousWord(result)
                && self.startsWithAlphaNumeric(trimmed)
            let splitLink = self.isSplitMarkdownLink(previous: result, next: trimmed)
                && !self.inlineCodeIsOpen(atEndOf: result)
            let shouldElideSpace = attachedHyphen || splitLink
            result += shouldElideSpace ? "" : " "
            result += trimmed
        }
        return self.collapseWhitespace(result)
    }

    /// A hyphen with no space before it stays attached (`well-`, `C++-`, `C#-`).
    /// A hyphen that is its own token (`dash -`) does not.
    private static func hyphenIsAttachedToPreviousWord(_ text: String) -> Bool {
        guard text.hasSuffix("-"), text.count >= 2 else { return false }
        let previous = text[text.index(text.endIndex, offsetBy: -2)]
        return !previous.isWhitespace
    }

    /// True when `text` ends inside a backtick span, so a later `](` is literal.
    /// The closing run has to match the opening run. A backslash escapes the next
    /// character only outside a span.
    private static func inlineCodeIsOpen(atEndOf text: String) -> Bool {
        var index = text.startIndex
        while index < text.endIndex {
            if text[index] == "\\" {
                let next = text.index(after: index)
                guard next < text.endIndex else { return false }
                index = text.index(after: next)
                continue
            }
            guard text[index] == "`" else {
                index = text.index(after: index)
                continue
            }
            let runEnd = text[index...].prefix(while: { $0 == "`" }).endIndex
            let length = text.distance(from: index, to: runEnd)
            var cursor = runEnd
            var closed = false
            while cursor < text.endIndex {
                if text[cursor] != "`" {
                    cursor = text.index(after: cursor)
                    continue
                }
                let closeEnd = text[cursor...].prefix(while: { $0 == "`" }).endIndex
                if text.distance(from: cursor, to: closeEnd) == length {
                    index = closeEnd
                    closed = true
                    break
                }
                cursor = closeEnd
            }
            if !closed {
                return true
            }
        }
        return false
    }

    /// Join `]` and `(` only when they are a real link, not a literal bracket
    /// followed by a parenthetical sentence.
    private static func isSplitMarkdownLink(previous: String, next: String) -> Bool {
        guard previous.hasSuffix("]"), next.hasPrefix("(") else { return false }
        let closeBracket = previous.index(before: previous.endIndex)
        if closeBracket > previous.startIndex, previous[previous.index(before: closeBracket)] == "\\" {
            return false
        }
        guard let open = previous.lastIndex(of: "[") else { return false }
        if open > previous.startIndex, previous[previous.index(before: open)] == "\\" {
            return false
        }
        let labelStart = previous.index(after: open)
        let labelEnd = previous.index(before: previous.endIndex)
        guard labelStart < labelEnd else { return false }
        let label = previous[labelStart..<labelEnd]
        guard !label.isEmpty, !label.contains("]"), !label.contains("[") else { return false }
        let destination = next.dropFirst()
        guard let close = Self.matchingLinkClose(in: destination) else { return false }
        return Self.markdownLinkInteriorIsValid(String(destination[..<close]))
    }

    /// The closing `)` matches the link, not a parenthesis inside the URL.
    private static func matchingLinkClose(in text: Substring) -> String.Index? {
        var depth = 0
        var quote: Character?
        var index = text.startIndex
        while index < text.endIndex {
            let character = text[index]
            if let active = quote {
                if character == active {
                    quote = nil
                }
            } else if character == "\"" || character == "'" {
                quote = character
            } else if character == "(" {
                depth += 1
            } else if character == ")" {
                if depth == 0 {
                    return index
                }
                depth -= 1
            }
            index = text.index(after: index)
        }
        return nil
    }

    /// The text inside `()` is a destination, or a destination plus a quoted title.
    /// `https://example.com is only an example` is prose.
    private static func markdownLinkInteriorIsValid(_ interior: String) -> Bool {
        let trimmed = interior.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return false }
        if trimmed.hasPrefix("<") {
            guard let end = trimmed.firstIndex(of: ">") else { return false }
            let after = trimmed[trimmed.index(after: end)...].drop(while: \.isWhitespace)
            if after.isEmpty {
                return true
            }
            return Self.isQuotedTitle(String(after))
        }
        let parts = trimmed.split(separator: " ", maxSplits: 1, omittingEmptySubsequences: true)
        guard let destination = parts.first, Self.isMarkdownDestination(String(destination)) else {
            return false
        }
        if parts.count == 1 {
            return true
        }
        return Self.isQuotedTitle(String(parts[1]))
    }

    private static func isQuotedTitle(_ text: String) -> Bool {
        guard text.count >= 2, let first = text.first, first == "\"" || first == "'" else { return false }
        return text.last == first
    }

    private static func isMarkdownDestination(_ destination: String) -> Bool {
        guard !destination.isEmpty, !destination.contains(" ") else { return false }
        if destination.hasPrefix("http://") || destination.hasPrefix("https://")
            || destination.hasPrefix("/") || destination.hasPrefix("#")
        {
            return true
        }
        return destination.contains(".") || destination.contains("/")
    }

    private static func startsWithAlphaNumeric(_ text: String) -> Bool {
        guard let first = text.unicodeScalars.first else { return false }
        return CharacterSet.alphanumerics.contains(first)
    }

    private static func collapseWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: CharacterSet.whitespaces)
    }
}
