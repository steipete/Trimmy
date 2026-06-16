import Foundation

enum TerminalAppIdentifiers {
    static let exactBundleIdentifiers: Set<String> = [
        "com.apple.terminal",
        "com.googlecode.iterm2",
        "com.mitchellh.ghostty",
        "dev.warp.warp",
        "dev.warp.warp-stable",
        "com.github.wez.wezterm",
        "org.alacritty",
        "co.zeit.hyper",
        "net.kovidgoyal.kitty",
        "com.cmuxterm.app",
    ]

    static let bundleIdentifierPrefixes: [String] = [
        "com.googlecode.iterm2",
    ]

    static let nameHints: [String] = [
        "terminal",
        "iterm",
        "ghostty",
        "warp",
        "wezterm",
        "alacritty",
        "hyper",
        "kitty",
        "cmux",
    ]

    static func isTerminal(bundleIdentifier: String?, appName: String?) -> Bool {
        if let bundleIdentifier {
            let lower = bundleIdentifier.lowercased()
            if Self.exactBundleIdentifiers.contains(lower) {
                return true
            }
            if Self.bundleIdentifierPrefixes.contains(where: { lower.hasPrefix($0) }) {
                return true
            }
        }

        let name = (appName ?? "").lowercased()
        return Self.nameHints.contains { name.contains($0) }
    }
}
