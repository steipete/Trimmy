import Foundation

public enum Aggressiveness: String, CaseIterable, Identifiable, Codable, Sendable {
    case low, normal, high
    public var id: String { self.rawValue }

    public var scoreThreshold: Int {
        switch self {
        case .low: 3
        case .normal: 2
        case .high: 1
        }
    }

    public var title: String {
        switch self {
        case .low: "Low (safer)"
        case .normal: "Normal"
        case .high: "High (more eager)"
        }
    }

    public var titleShort: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        }
    }

    /// Short helper text shown under the radio group.
    public var blurb: String {
        switch self {
        case .low:
            "Keeps light multi-line snippets intact unless they clearly look like shell commands."
        case .normal:
            "Good default: flattens typical blog/README commands with pipes or continuations."
        case .high:
            "Most eager: will flatten almost any short multi-line text that resembles a command."
        }
    }
}
