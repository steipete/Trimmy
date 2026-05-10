import Foundation
import TrimmyCore

public enum GeneralAggressiveness: String, CaseIterable, Identifiable, Codable, Sendable {
    case none
    case low
    case normal
    case high

    public var id: String {
        self.rawValue
    }

    public var title: String {
        switch self {
        case .none:
            "None (no auto-trim)"
        case .low:
            Aggressiveness.low.title
        case .normal:
            Aggressiveness.normal.title
        case .high:
            Aggressiveness.high.title
        }
    }

    public var titleShort: String {
        switch self {
        case .none: "None"
        case .low: Aggressiveness.low.titleShort
        case .normal: Aggressiveness.normal.titleShort
        case .high: Aggressiveness.high.titleShort
        }
    }

    public var blurb: String {
        switch self {
        case .none:
            "Skip auto-flattening for non-terminal apps. Manual “Paste Trimmed” still uses High."
        case .low:
            Aggressiveness.low.blurb
        case .normal:
            Aggressiveness.normal.blurb
        case .high:
            Aggressiveness.high.blurb
        }
    }

    public var coreAggressiveness: Aggressiveness? {
        switch self {
        case .none:
            nil
        case .low:
            .low
        case .normal:
            .normal
        case .high:
            .high
        }
    }
}
