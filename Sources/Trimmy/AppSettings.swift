import ServiceManagement
import SwiftUI
import TrimmyCore

@MainActor
public final class AppSettings: ObservableObject {
    @AppStorage("generalAggressiveness") public var generalAggressiveness: GeneralAggressiveness = .low
    @AppStorage("terminalAggressiveness") public var terminalAggressiveness: Aggressiveness = .normal
    @AppStorage("preserveBlankLines") public var preserveBlankLines: Bool = false
    @AppStorage("autoTrimEnabled") public var autoTrimEnabled: Bool = true
    @AppStorage("contextAwareTrimmingEnabled") public var contextAwareTrimmingEnabled: Bool = true
    @AppStorage("removeBoxDrawing") public var removeBoxDrawing: Bool = true
    @AppStorage("hideMenuBarIcon") var hideMenuBarIcon: Bool = false
    @AppStorage("flattenClaudeCodePrompts") public var flattenClaudeCodePrompts: Bool = true
    @AppStorage("usePasteboardFallbacks") var usePasteboardFallbacks: Bool = false
    @AppStorage("showMarkdownReformatOption") var showMarkdownReformatOption: Bool = true
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { LaunchAtLoginManager.setEnabled(self.launchAtLogin) }
    }

    @AppStorage("trimHotkeyEnabled") var pasteTrimmedHotkeyEnabled: Bool = true {
        didSet { self.pasteTrimmedHotkeyEnabledChanged?(self.pasteTrimmedHotkeyEnabled) }
    }

    @AppStorage("pasteOriginalHotkeyEnabled") var pasteOriginalHotkeyEnabled: Bool = false {
        didSet { self.pasteOriginalHotkeyEnabledChanged?(self.pasteOriginalHotkeyEnabled) }
    }

    @AppStorage("autoTrimHotkeyEnabled") var autoTrimHotkeyEnabled: Bool = false {
        didSet { self.autoTrimHotkeyEnabledChanged?(self.autoTrimHotkeyEnabled) }
    }

    var pasteTrimmedHotkeyEnabledChanged: ((Bool) -> Void)?
    var pasteOriginalHotkeyEnabledChanged: ((Bool) -> Void)?
    var autoTrimHotkeyEnabledChanged: ((Bool) -> Void)?

    #if DEBUG
    @AppStorage("debugPaneEnabled") var debugPaneEnabled: Bool = false
    #endif

    public init() {
        Self.migrateAggressivenessDefaults()
        LaunchAtLoginManager.setEnabled(self.launchAtLogin)
    }
}

extension AppSettings {
    private static let legacyAggressivenessKey = "aggressiveness"
    private static let generalAggressivenessKey = "generalAggressiveness"
    private static let terminalAggressivenessKey = "terminalAggressiveness"

    private static func migrateAggressivenessDefaults() {
        let defaults = UserDefaults.standard
        let legacyRaw = defaults.string(forKey: Self.legacyAggressivenessKey)

        if defaults.object(forKey: Self.generalAggressivenessKey) == nil,
           let legacyRaw,
           let legacy = Aggressiveness(rawValue: legacyRaw)
        {
            defaults.set(legacy.rawValue, forKey: Self.generalAggressivenessKey)
        }

        if defaults.object(forKey: Self.terminalAggressivenessKey) == nil {
            if let legacyRaw, let legacy = Aggressiveness(rawValue: legacyRaw) {
                defaults.set(legacy.rawValue, forKey: Self.terminalAggressivenessKey)
            } else {
                defaults.set(Aggressiveness.normal.rawValue, forKey: Self.terminalAggressivenessKey)
            }
        }
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
