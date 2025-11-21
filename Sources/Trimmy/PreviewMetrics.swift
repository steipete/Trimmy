import Foundation

enum PreviewMetrics {
    static func charCountSuffix(count: Int, limit: Int? = nil, showTruncations: Bool = true) -> String {
        let truncations = showTruncations ? (limit.map { self.truncationCount(for: count, limit: $0) } ?? 0) : 0
        if count >= 1000 {
            let k = Double(count) / 1000.0
            let formatted = k >= 10 ? String(format: "%.0fk", k) : String(format: "%.1fk", k)
            return truncations > 0
                ? " (\(formatted) chars, \(truncations) truncations)"
                : " (\(formatted) chars)"
        } else {
            return truncations > 0
                ? " (\(count) chars, \(truncations) truncations)"
                : " (\(count) chars)"
        }
    }

    static func displayString(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "⏎ ")
            .replacingOccurrences(of: "\t", with: "⇥ ")
    }

    private static func truncationCount(for count: Int, limit: Int) -> Int {
        guard count > limit, limit > 0 else { return 0 }
        return (count - 1) / limit
    }
}
