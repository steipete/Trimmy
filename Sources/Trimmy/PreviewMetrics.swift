import Foundation

enum PreviewMetrics {
    static func charCountSuffix(count: Int) -> String {
        " (\(self.formattedChars(count)))"
    }

    static func prettyBadge(count: Int) -> String {
        " · \(self.formattedChars(count))"
    }

    static func displayString(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "⏎ ")
            .replacingOccurrences(of: "\t", with: "⇥ ")
    }

    static func displayStringWithVisibleWhitespace(_ text: String) -> String {
        text
            .replacingOccurrences(of: " ", with: "·")
            .replacingOccurrences(of: "\t", with: "⇥")
            .replacingOccurrences(of: "\n", with: "⏎")
    }

    /// Map a source string to a visible-whitespace string while carrying per-character flags.
    /// Each source character expands to exactly one visible character so indices stay aligned.
    static func mapToVisibleWhitespace(_ text: String, removed: [Bool]) -> (String, [Bool]) {
        precondition(text.count == removed.count, "removed flags must match character count")
        var mapped = ""
        var mappedRemoved: [Bool] = []
        for (ch, flag) in zip(text, removed) {
            let out: Character = switch ch {
            case " ": "·"
            case "\t": "⇥"
            case "\n": "⏎"
            default: ch
            }
            mapped.append(out)
            mappedRemoved.append(flag)
        }
        return (mapped, mappedRemoved)
    }

    private static func formattedChars(_ count: Int) -> String {
        count >= 1000 ? "\(self.kString(count)) chars" : "\(count) chars"
    }

    private static func kString(_ count: Int) -> String {
        let k = Double(count) / 1000.0
        return k >= 10 ? String(format: "%.0f", k) + "k" : String(format: "%.1f", k) + "k"
    }
}
