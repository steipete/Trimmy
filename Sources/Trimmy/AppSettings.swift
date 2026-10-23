import ServiceManagement
import SwiftUI
import TrimmyCore

@MainActor
public final class AppSettings: ObservableObject {
    @AppStorage("generalAggressiveness") public var generalAggressiveness: GeneralAggressiveness = .low
    @AppStorage("terminalAggressiveness") public var terminalAggressiveness: Aggressiveness = .normal
    @AppStorage("preserveBlankLines") public var preserveBlankLines: Bool = false
    @AppStorage("autoTrimEnabled") public var autoTrimEnabled: Bool = true
    @AppStorage("autoTrimExcludedApps") public var autoTrimExcludedApps: String = ""
    @AppStorage("autoTrimExcludedSites") public var autoTrimExcludedSites: String = ""
    @AppStorage("contextAwareTrimmingEnabled") public var contextAwareTrimmingEnabled: Bool = true
    @AppStorage("removeBoxDrawing") public var removeBoxDrawing: Bool = true
    @AppStorage("hideMenuBarIcon") var hideMenuBarIcon: Bool = false
    @AppStorage("flattenClaudeCodePrompts") public var flattenClaudeCodePrompts: Bool = true
    @AppStorage("showURLQueryParamStripOption") public var showURLQueryParamStripOption: Bool = true
    @AppStorage("urlQueryParamCustomRules") public var urlQueryParamCustomRules: String = URLQueryParamRules
        .defaultRulesText
    {
        didSet { self.refreshParsedURLQueryParamRules() }
    }

    // Cached parse of urlQueryParamCustomRules. Recomputed only when the raw string changes, so the
    // menu's per-render rule lookup doesn't re-split/-trim/-lowercase the text on every body re-render.
    @Published public private(set) var parsedURLQueryParamRules: [URLQueryParamRule] = []
    @AppStorage("usePasteboardFallbacks") var usePasteboardFallbacks: Bool = false
    @AppStorage("showMarkdownReformatOption") var showMarkdownReformatOption: Bool = true
    @AppStorage("autoReflowTextEnabled") var autoReflowTextEnabled: Bool = false
    @AppStorage("trimLeadingBlankLinesOnReflow") var trimLeadingBlankLinesOnReflow: Bool = false
    @Published private(set) var launchAtLoginError: String?
    private let updateLoginItem: (Bool) throws -> Void
    private var isApplyingLaunchAtLogin = false
    @AppStorage("launchAtLogin") var launchAtLogin: Bool = false {
        didSet { self.applyLaunchAtLoginChange(from: oldValue) }
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

    public convenience init() {
        self.init(updateLoginItem: LaunchAtLoginManager.setEnabled)
    }

    init(updateLoginItem: @escaping (Bool) throws -> Void) {
        self.updateLoginItem = updateLoginItem
        Self.migrateShortcutDefaults(.standard)
        Self.migrateAggressivenessDefaults()
        self.applyLaunchAtLoginOnLaunch()
        self.refreshParsedURLQueryParamRules()
    }

    private func applyLaunchAtLoginChange(from previous: Bool) {
        guard !self.isApplyingLaunchAtLogin else { return }
        do {
            try self.updateLoginItem(self.launchAtLogin)
            self.launchAtLoginError = nil
        } catch {
            self.isApplyingLaunchAtLogin = true
            self.launchAtLogin = previous
            self.isApplyingLaunchAtLogin = false
            self.launchAtLoginError = LaunchAtLoginManager.recoveryMessage(for: error)
        }
    }

    /// Startup applies the saved choice. A failure is shown later and does not rewrite the saved toggle.
    private func applyLaunchAtLoginOnLaunch() {
        do {
            try self.updateLoginItem(self.launchAtLogin)
            self.launchAtLoginError = nil
        } catch {
            self.launchAtLoginError = LaunchAtLoginManager.recoveryMessage(for: error)
        }
    }

    private func refreshParsedURLQueryParamRules() {
        self.parsedURLQueryParamRules = URLQueryParamRules.parseCustomRules(self.urlQueryParamCustomRules)
    }
}

extension AppSettings {
    static func migrateShortcutDefaults(_ defaults: UserDefaults) {
        let migrationKey = "hasMigratedInitialShortcuts"
        guard !defaults.bool(forKey: migrationKey) else { return }
        let shortcutKeys = ["KeyboardShortcuts_trimClipboard", "KeyboardShortcuts_pasteOriginal"]
        let existingKeys = shortcutKeys + ["aggressiveness", "terminalAggressiveness"]
        if existingKeys.contains(where: { defaults.object(forKey: $0) != nil }) {
            // Older names removed cleared entries; the SDK's false sentinel preserves that choice.
            for key in shortcutKeys where defaults.object(forKey: key) == nil {
                defaults.set(false, forKey: key)
            }
        }
        defaults.set(true, forKey: migrationKey)
    }

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
    static func recoveryMessage(for error: Error) -> String {
        "Start at Login could not be changed (\(error.localizedDescription)). "
            + "Try the toggle again, or allow Trimmy in System Settings, General, Login Items."
    }

    @MainActor
    static func setEnabled(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            switch service.status {
            case .enabled, .requiresApproval:
                // Pending approval is a successful registration; keep the requested preference.
                return
            default:
                try service.register()
            }
        } else {
            switch service.status {
            case .notRegistered, .notFound:
                return
            default:
                try service.unregister()
            }
        }
    }
}
