import ServiceManagement
import SwiftUI

enum Aggressiveness: String, CaseIterable, Identifiable, Codable {
    case low, normal, high
    var id: String { rawValue }

    var scoreThreshold: Int {
        switch self {
        case .low: 3
        case .normal: 2
        case .high: 1
        }
    }
}

extension Aggressiveness {
    var title: String {
        switch self {
        case .low: "Low (safer)"
        case .normal: "Normal"
        case .high: "High (more eager)"
        }
    }

    var titleShort: String {
        switch self {
        case .low: "Low"
        case .normal: "Normal"
        case .high: "High"
        }
    }

    /// Short helper text shown under the radio group.
    var blurb: String {
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

@MainActor
final class AppSettings: ObservableObject {
    @AppStorage("aggressiveness") var aggressiveness: Aggressiveness = .normal
    @AppStorage("preserveBlankLines") var preserveBlankLines: Bool = false
    @AppStorage("autoTrimEnabled") var autoTrimEnabled: Bool = true
    @AppStorage("removeBoxDrawing") var removeBoxDrawing: Bool = true
    @AppStorage("usePasteboardFallbacks") var usePasteboardFallbacks: Bool = false
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { LaunchAtLoginManager.setEnabled(self.launchAtLogin) }
    }

    @AppStorage("trimHotkeyEnabled") var trimHotkeyEnabled: Bool = true {
        didSet { self.trimHotkeyEnabledChanged?(self.trimHotkeyEnabled) }
    }

    @AppStorage("autoTrimHotkeyEnabled") var autoTrimHotkeyEnabled: Bool = false {
        didSet { self.autoTrimHotkeyEnabledChanged?(self.autoTrimHotkeyEnabled) }
    }

    var trimHotkeyEnabledChanged: ((Bool) -> Void)?
    var autoTrimHotkeyEnabledChanged: ((Bool) -> Void)?

    init() {
        LaunchAtLoginManager.setEnabled(self.launchAtLogin)
    }
}

enum LaunchAtLoginManager {
    @MainActor
    static func setEnabled(_ enabled: Bool) {
        guard #available(macOS 13, *) else { return }
        let service = SMAppService.mainApp
        if enabled {
            try? service.register()
        } else {
            try? service.unregister()
        }
    }
}
