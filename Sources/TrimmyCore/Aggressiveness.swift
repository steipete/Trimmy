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
        case .low: "Niedrig (sicherer)"
        case .normal: "Normal"
        case .high: "Hoch (aggressiver)"
        }
    }

    public var titleShort: String {
        switch self {
        case .low: "Niedrig"
        case .normal: "Normal"
        case .high: "Hoch"
        }
    }

    /// Short helper text shown under the radio group.
    public var blurb: String {
        switch self {
        case .low:
            "Lässt mehrzeilige Snippets intakt, außer sie sehen eindeutig wie Shell-Befehle aus."
        case .normal:
            "Guter Standard: Faltet typische Blog-/README-Befehle mit Pipes oder Fortsetzungen zusammen."
        case .high:
            "Am aggressivsten: Faltet fast jeden kurzen mehrzeiligen Text zusammen, der wie ein Befehl aussieht."
        }
    }
}
