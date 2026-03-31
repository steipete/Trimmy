import Foundation
import TrimmyCore

public enum GeneralAggressiveness: String, CaseIterable, Identifiable, Codable, Sendable {
    case none
    case low
    case normal
    case high

    public var id: String { self.rawValue }

    public var title: String {
        switch self {
        case .none:
            "Keine (kein Auto-Trim)"
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
        case .none: "Keine"
        case .low: Aggressiveness.low.titleShort
        case .normal: Aggressiveness.normal.titleShort
        case .high: Aggressiveness.high.titleShort
        }
    }

    public var blurb: String {
        switch self {
        case .none:
            "Auto-Flattening für Nicht-Terminal-Apps überspringen. Manuelles “Getrimmt einfügen” nutzt weiterhin Hoch.”
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
