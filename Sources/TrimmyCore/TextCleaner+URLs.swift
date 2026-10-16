import Foundation

extension TextCleaner {
    /// Strips query parameters from a clipboard URL, preserving any param names in `keeping`.
    /// Returns nil if the text is not a single bare URL, has no query string, or nothing was removed.
    /// Uses percentEncodedQueryItems to preserve the original percent-encoding in values (e.g. %3A).
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
        guard var components = URLComponents(string: trimmed) else { return nil }
        let original = components.percentEncodedQueryItems ?? []
        guard !original.isEmpty else { return nil }
        let keeping = resolveKeeping(components.host ?? "")
        if keeping.isEmpty {
            components.percentEncodedQueryItems = nil
        } else {
            let filtered = original.filter { item in
                guard let name = item.name.removingPercentEncoding else { return false }
                return keeping.contains(name)
            }
            guard filtered.count < original.count else { return nil }
            components.percentEncodedQueryItems = filtered.isEmpty ? nil : filtered
        }
        guard let stripped = components.url?.absoluteString else { return nil }
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
        guard pieces.count >= 2, Self.piecesAreOneWrappedURL(pieces) else { return nil }

        let collapsed = pieces.joined()
        guard collapsed != trimmed else { return nil }

        let validURLPattern = #"^https?://[A-Za-z0-9._~:/?#\\[\\]@!$&'()*+,;=%-]+$"#
        guard collapsed.range(of: validURLPattern, options: .regularExpression) != nil else { return nil }

        return collapsed
    }

    /// Whitespace belongs inside one URL when each later piece continues a broken token.
    /// `bar= two` continues the value. `https://example.com please` does not.
    private static func piecesAreOneWrappedURL(_ pieces: [String]) -> Bool {
        let piecePattern = #"^[A-Za-z0-9._~:/?#\\[\\]@!$&'()*+,;=%-]+$"#
        guard pieces.allSatisfy({ $0.range(of: piecePattern, options: .regularExpression) != nil }) else {
            return false
        }

        var accumulated = ""
        for (index, piece) in pieces.enumerated() {
            if index > 0, Self.wrappedURLIsComplete(accumulated), Self.isSeparateWord(piece) {
                return false
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
    private static let wrappedURLBreakMarkers: Set<Character> = ["-", "=", "&", "?", "/", "%", "#"]

    /// Quotes a filesystem path that contains spaces so it can be used directly in shell commands.
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

        // Keep home expansion outside quotes; the rest of the path is literal shell data.
        let isHomeRelative = trimmed.hasPrefix("~/")
        let path = isHomeRelative ? String(trimmed.dropFirst(2)) : trimmed
        let escaped = path.replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "$", with: "\\$")
            .replacingOccurrences(of: "`", with: "\\`")
        return (isHomeRelative ? "~/" : "") + "\"\(escaped)\""
    }
}
