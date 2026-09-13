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
        guard !trimmed.contains("\n") else { return nil }
        let lowered = trimmed.lowercased()
        guard lowered.hasPrefix("http://") || lowered.hasPrefix("https://") else { return nil }
        guard var components = URLComponents(string: trimmed) else { return nil }
        let original = components.percentEncodedQueryItems ?? []
        guard !original.isEmpty else { return nil }
        let keeping = resolveKeeping(components.host ?? "")
        if keeping.isEmpty {
            components.percentEncodedQueryItems = nil
        } else {
            let filtered = original.filter { keeping.contains($0.name) }
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
}
