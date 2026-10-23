import Foundation

extension TextCleaner {
    /// Strips query parameters from a clipboard URL, preserving any param names in `keeping`.
    /// Returns nil if the text is not a single bare URL, has no query string, or nothing was removed.
    /// Copies retained fields verbatim so malformed escapes and their original spelling are preserved.
    public func stripURLQueryParams(_ text: String, keeping: Set<String> = []) -> String? {
        self.stripURLQueryParams(text) { _ in keeping }
    }

    /// Host-aware variant: parses the URL once and asks the caller which params to keep for the
    /// resolved host. Used by production code so rule lookup doesn't require a second URLComponents parse.
    public func stripURLQueryParams(
        _ text: String,
        resolveKeeping: (_ host: String) -> Set<String>) -> String?
    {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.contains(where: \.isWhitespace) else { return nil }
        let lowered = trimmed.lowercased()
        guard lowered.hasPrefix("http://") || lowered.hasPrefix("https://") else { return nil }
        guard let components = URLComponents(string: trimmed) else { return nil }
        guard let queryIndex = trimmed.firstIndex(of: "?") else { return nil }
        if let hashIndex = trimmed.firstIndex(of: "#"), hashIndex < queryIndex {
            return nil
        }
        let keeping = resolveKeeping(components.host ?? "")
        let head = trimmed[..<queryIndex]
        let remainder = trimmed[trimmed.index(after: queryIndex)...]
        let rawQuery: Substring
        let fragment: Substring
        if let hash = remainder.firstIndex(of: "#") {
            rawQuery = remainder[..<hash]
            fragment = remainder[hash...]
        } else {
            rawQuery = remainder
            fragment = ""
        }
        guard !rawQuery.isEmpty else { return nil }

        let parts = rawQuery.split(separator: "&", omittingEmptySubsequences: false)
        let kept: [Substring]
        if keeping.isEmpty {
            kept = []
        } else {
            kept = parts.filter { part in
                let nameSource: Substring = if let equals = part.firstIndex(of: "=") {
                    part[..<equals]
                } else {
                    part
                }
                guard let name = String(nameSource).removingPercentEncoding else { return false }
                return keeping.contains(name)
            }
            guard kept.count < parts.count else { return nil }
        }

        let stripped = if kept.isEmpty {
            String(head) + String(fragment)
        } else {
            String(head) + "?" + kept.joined(separator: "&") + String(fragment)
        }
        return stripped == trimmed ? nil : stripped
    }

    public func repairWrappedURL(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let lowercased = trimmed.lowercased()
        let schemeCount = (lowercased.components(separatedBy: "https://").count - 1)
            + (lowercased.components(separatedBy: "http://").count - 1)
        guard schemeCount == 1 else { return nil }
        guard lowercased.hasPrefix("http://") || lowercased.hasPrefix("https://") else { return nil }

        let pieces = trimmed.split(whereSeparator: \.isWhitespace).map(String.init)
        guard pieces.count >= 2, Self.piecesAreOneWrappedURL(pieces, text: trimmed) else { return nil }

        let collapsed = pieces.joined()
        guard collapsed != trimmed else { return nil }

        let validURLPattern = #"^https?://[A-Za-z0-9._~:/?#\\[\\]@!$&'()*+,;=%-]+$"#
        guard collapsed.range(of: validURLPattern, options: .regularExpression) != nil else { return nil }

        return collapsed
    }

    /// Whitespace belongs inside one URL when each later piece continues a broken token.
    /// `bar= two` continues the value. `https://example.com please` does not.
    private static func piecesAreOneWrappedURL(_ pieces: [String], text: String) -> Bool {
        let piecePattern = #"^[A-Za-z0-9._~:/?#\\[\\]@!$&'()*+,;=%-]+$"#
        guard pieces.allSatisfy({ $0.range(of: piecePattern, options: .regularExpression) != nil }) else {
            return false
        }

        let lineWrappedTokens = text.contains(where: \.isNewline)
            && text.split(whereSeparator: \.isNewline).allSatisfy {
                $0.split(whereSeparator: \.isWhitespace).count == 1
            }
        var accumulated = ""
        for (index, piece) in pieces.enumerated() {
            if index > 0, Self.wrappedURLIsComplete(accumulated), Self.isSeparateWord(piece) {
                // Token-only lines can continue a path, query, or fragment.
                // Spaces or multiword lines are prose; a bare host has no token to continue.
                let components = URLComponents(string: accumulated)
                let hasToken = !(components?.path.isEmpty ?? true)
                    || components?.query != nil || components?.fragment != nil
                guard lineWrappedTokens, hasToken else { return false }
            }
            accumulated += piece
        }
        return true
    }

    private static func wrappedURLIsComplete(_ text: String) -> Bool {
        guard let url = URL(string: text), let host = url.host, !host.isEmpty else { return false }
        if Self.unfinishedSingleHostLabel(url) {
            return false
        }
        guard let last = text.last else { return false }
        return !Self.wrappedURLBreakMarkers.contains(last)
    }

    /// `https://example.` still needs the next host label. `https://example.com.` is finished.
    private static func unfinishedSingleHostLabel(_ url: URL) -> Bool {
        guard let host = url.host, host.hasSuffix(".") else { return false }
        let labels = host.split(separator: ".", omittingEmptySubsequences: false)
        guard labels.count == 2, labels[1].isEmpty, !labels[0].isEmpty else { return false }
        return url.path.isEmpty && url.query == nil && url.fragment == nil
    }

    /// A following token is prose when it is a word, including `thanks!` and `version2`.
    /// `ple.com` and `path?foo=1` stay URL continuations.
    private static func isSeparateWord(_ piece: String) -> Bool {
        var core = piece
        while let last = core.last, Self.trailingProsePunctuation.contains(last) {
            core.removeLast()
        }
        guard let first = core.first, first.isLetter else { return false }
        return core.allSatisfy { character in
            character.isLetter || character.isNumber || character == "'" || character == "-"
        }
    }

    private static let trailingProsePunctuation: Set<Character> = ["!", "?", ",", ".", ";", ":"]
    private static let wrappedURLBreakMarkers: Set<Character> = ["-", "=", "&", "?", "%", "#"]

    /// Quotes an existing filesystem path that contains spaces for use in shell commands.
    /// Returns nil if no transformation is needed.
    public func quotePathWithSpaces(_ text: String) -> String? {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip if empty or multi-line
        guard !trimmed.isEmpty, !trimmed.contains(where: \.isNewline) else { return nil }

        // Skip if already quoted
        if (trimmed.hasPrefix("\"") && trimmed.hasSuffix("\""))
            || (trimmed.hasPrefix("'") && trimmed.hasSuffix("'"))
        {
            return nil
        }

        guard trimmed.contains(" "), !trimmed.contains("://") else { return nil }

        // Keep home expansion outside quotes; the rest of the path is literal shell data.
        let isHomeRelative = trimmed.hasPrefix("~/")
        let resolvedPath = isHomeRelative ? (trimmed as NSString).expandingTildeInPath : trimmed
        guard FileManager.default.fileExists(atPath: resolvedPath) else { return nil }

        let path = isHomeRelative ? String(trimmed.dropFirst(2)) : trimmed
        let escaped = path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
        return (isHomeRelative ? "~/" : "") + "\"\(escaped)\""
    }
}
