import Foundation

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
        self.isLikelyMarkdown(text) || self.hasLikelyHardWrappedParagraph(text)
    }

    static func reformat(_ text: String, trimLeadingBlankLines: Bool = true) -> String {
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
            return paragraphLines.dropLast().contains { line in
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
        return count >= fence.count
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
        while index < rest.endIndex, rest[index].isNumber {
            digits.append(rest[index])
            index = rest.index(after: index)
        }
        guard !digits.isEmpty, index < rest.endIndex else { return nil }
        let markerChar = rest[index]
        guard markerChar == "." || markerChar == ")" else { return nil }
        var contentStart = rest.index(after: index)
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
            let shouldElideSpace = result.hasSuffix("-") && self.startsWithAlphaNumeric(trimmed)
            result += shouldElideSpace ? "" : " "
            result += trimmed
        }
        return self.collapseWhitespace(result)
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
