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
        case .low: NSLocalizedString("Low (safer)", bundle: .trimmyCoreSafeBundle, comment: "Aggressiveness level")
        case .normal: NSLocalizedString("Normal", bundle: .trimmyCoreSafeBundle, comment: "Aggressiveness level")
        case .high: NSLocalizedString("High (more eager)", bundle: .trimmyCoreSafeBundle, comment: "Aggressiveness level")
        }
    }

    public var titleShort: String {
        switch self {
        case .low: NSLocalizedString("Low", bundle: .trimmyCoreSafeBundle, comment: "Aggressiveness short")
        case .normal: NSLocalizedString("Normal", bundle: .trimmyCoreSafeBundle, comment: "Aggressiveness short")
        case .high: NSLocalizedString("High", bundle: .trimmyCoreSafeBundle, comment: "Aggressiveness short")
        }
    }

    /// Short helper text shown under the radio group.
    public var blurb: String {
        switch self {
        case .low:
            NSLocalizedString("Keeps light multi-line snippets intact unless they clearly look like shell commands.", bundle: .trimmyCoreSafeBundle, comment: "")
        case .normal:
            NSLocalizedString("Good default: flattens typical blog/README commands with pipes or continuations.", bundle: .trimmyCoreSafeBundle, comment: "")
        case .high:
            NSLocalizedString("Most eager: will flatten almost any short multi-line text that resembles a command.", bundle: .trimmyCoreSafeBundle, comment: "")
        }
    }
}
