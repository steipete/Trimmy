import Foundation

enum PreviewMetrics {
    static func charCountSuffix(count: Int) -> String {
        if count >= 1000 {
            let k = Double(count) / 1000.0
            let formatted = k >= 10 ? String(format: "%.0fk", k) : String(format: "%.1fk", k)
            return " (\(formatted) chars)"
        } else {
            return " (\(count) chars)"
        }
    }

    static func displayString(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\n", with: "⏎ ")
            .replacingOccurrences(of: "\t", with: "⇥ ")
    }
}
