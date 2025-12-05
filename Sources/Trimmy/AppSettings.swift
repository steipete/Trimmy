import ServiceManagement
import SwiftUI
import TrimmyCore

@MainActor
public final class AppSettings: ObservableObject {
    @AppStorage("aggressiveness") public var aggressiveness: Aggressiveness = .normal
    @AppStorage("preserveBlankLines") public var preserveBlankLines: Bool = false
    @AppStorage("autoTrimEnabled") public var autoTrimEnabled: Bool = true
    @AppStorage("removeBoxDrawing") public var removeBoxDrawing: Bool = true
    @AppStorage("usePasteboardFallbacks") var usePasteboardFallbacks: Bool = false
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
