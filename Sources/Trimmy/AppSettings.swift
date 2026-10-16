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
    @Published var launchAtLoginError: String?
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

    public init() {
        Self.migrateShortcutDefaults(.standard)
        Self.migrateAggressivenessDefaults()
        self.applyLaunchAtLoginOnLaunch()
        self.refreshParsedURLQueryParamRules()
    }

    private func applyLaunchAtLoginChange(from previous: Bool) {
        guard !self.isApplyingLaunchAtLogin else { return }
        let change = LaunchAtLoginChange.applying(self.launchAtLogin, previous: previous) {
            try LaunchAtLoginManager.setEnabled($0)
        }
        if change.enabled != self.launchAtLogin {
            self.isApplyingLaunchAtLogin = true
            self.launchAtLogin = change.enabled
            self.isApplyingLaunchAtLogin = false
        }
        self.launchAtLoginError = change.error
    }

    /// Startup applies the saved choice. A failure is shown later and does not rewrite the saved toggle.
    private func applyLaunchAtLoginOnLaunch() {
        do {
            try LaunchAtLoginManager.setEnabled(self.launchAtLogin)
            self.launchAtLoginError = nil
        } catch {
            self.launchAtLoginError = LaunchAtLoginChange.recoveryMessage(for: error)
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

struct LaunchAtLoginChange: Equatable {
    var enabled: Bool
    var error: String?

    static func recoveryMessage(for error: Error) -> String {
        "Start at Login could not be changed (\(error.localizedDescription)). "
            + "Try the toggle again, or allow Trimmy in System Settings, General, Login Items."
    }

    static func applying(
        _ requested: Bool,
        previous: Bool,
        perform: (Bool) throws -> Void) -> LaunchAtLoginChange
    {
        do {
            try perform(requested)
            return LaunchAtLoginChange(enabled: requested, error: nil)
        } catch {
            return LaunchAtLoginChange(enabled: previous, error: self.recoveryMessage(for: error))
        }
    }
}

enum LaunchAtLoginManager {
    struct Failure: LocalizedError {
        var message: String
        var errorDescription: String? {
            self.message
        }
    }

    /// Nil in the app, which then uses SMAppService. A caller can supply a closure to exercise failures.
    @MainActor static var setEnabledBody: ((Bool) throws -> Void)?

    @MainActor
    static func setEnabled(_ enabled: Bool) throws {
        if let setEnabledBody {
            try setEnabledBody(enabled)
            return
        }
        try Self.updateService(enabled)
    }

    @MainActor
    private static func updateService(_ enabled: Bool) throws {
        let service = SMAppService.mainApp
        if enabled {
            switch service.status {
            case .enabled:
                return
            case .requiresApproval:
                throw Failure(message: "Start at Login is waiting for approval in System Settings.")
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
