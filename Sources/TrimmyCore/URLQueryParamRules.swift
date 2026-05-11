import Foundation

public struct URLQueryParamRule: Sendable {
    public let domain: String
    public let keepParams: Set<String>

    public init(domain: String, keepParams: Set<String>) {
        self.domain = domain
        self.keepParams = keepParams
    }
}

public enum URLQueryParamRules {
    /// Built-in per-domain rules for params that are content identity, not tracking.
    /// "Content identity" means the URL is broken or points to the wrong thing without the param.
    public static let builtIn: [URLQueryParamRule] = [
        // `v` is the video ID — /watch without it is an empty page, not a video.
        // `list` carries the playlist context; stripping it drops the queue and playlist UI.
        // `t` links to a specific timestamp; stripping it loses the intended moment in the video.
        .init(domain: "youtube.com", keepParams: ["v", "list", "t"]),

        // On short links the video ID is already in the path (youtu.be/ID),
        // so only `t` carries additional content identity.
        .init(domain: "youtu.be", keepParams: ["t"]),

        // `tab` identifies which tab is active in a multi-tab document.
        // A heading anchor on tab 2 silently breaks if ?tab= is stripped and the user lands on tab 0.
        .init(domain: "docs.google.com", keepParams: ["tab"]),
        .init(domain: "sheets.google.com", keepParams: ["tab"]),
        .init(domain: "slides.google.com", keepParams: ["tab"]),

        // `q` is the place name or search query — without it you get a blank map.
        // `ll` is the lat/lng center of the map view; stripping it loses the viewport.
        // `z` is the zoom level; meaningless alone but provides context alongside ll.
        .init(domain: "maps.google.com", keepParams: ["q", "ll", "z"]),

        // `tab` selects which repo section is shown (Issues, Actions, Pull Requests, etc.).
        // Stripping it always lands on the Code tab regardless of what was shared.
        .init(domain: "github.com", keepParams: ["tab"]),

        // `file` identifies which file is open in the editor.
        // Stripping it lands on the sandbox's default entry point, not the shared file.
        .init(domain: "codesandbox.io", keepParams: ["file"]),

        // `node-id` links to a specific frame, component, or layer in a Figma file.
        // Without it the link opens the file root, which may have hundreds of frames.
        .init(domain: "figma.com", keepParams: ["node-id"]),
    ]

    /// Parses user-defined rules from a plain-text string.
    /// Format: one rule per line — `domain.com: param1, param2`
    /// Blank lines and lines without a colon are ignored.
    public static func parseCustomRules(_ text: String) -> [URLQueryParamRule] {
        text.split(omittingEmptySubsequences: true, whereSeparator: \.isNewline)
            .compactMap { line -> URLQueryParamRule? in
                let parts = line.split(separator: ":", maxSplits: 1)
                guard parts.count == 2 else { return nil }
                let domain = parts[0].trimmingCharacters(in: .whitespaces).lowercased()
                guard !domain.isEmpty else { return nil }
                let params = parts[1]
                    .split(separator: ",")
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                guard !params.isEmpty else { return nil }
                return URLQueryParamRule(domain: domain, keepParams: Set(params))
            }
    }

    /// Returns the set of params to keep for a given host.
    /// Matching is done on host suffix so `youtube.com` catches `www.youtube.com`.
    public static func keepParams(for host: String, customRules: [URLQueryParamRule]) -> Set<String> {
        guard let match = customRules.first(where: {
            host == $0.domain || host.hasSuffix(".\($0.domain)")
        }) else { return [] }
        return match.keepParams
    }

    /// The default rules text to pre-populate the settings text area on first launch.
    public static let defaultRulesText: String = builtIn
        .map { "\($0.domain): \($0.keepParams.sorted().joined(separator: ", "))" }
        .joined(separator: "\n")
}
