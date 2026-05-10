import AppKit
import MenuBarExtraAccess
import Observation
import QuartzCore
import Security
import SwiftUI

@main
@MainActor
struct TrimmyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var settings = AppSettings()
    @StateObject private var permissions = AccessibilityPermissionManager()
    @StateObject private var monitor: ClipboardMonitor
    @StateObject private var hotkeyManager: HotkeyManager
    @State private var isMenuPresented = false
    @State private var statusItem: NSStatusItem?
    private let startupDiagnostics = StartupDiagnostics()

    init() {
        let settings = AppSettings()
        let permissions = AccessibilityPermissionManager()
        let monitor = ClipboardMonitor(settings: settings, accessibilityPermission: permissions)
        monitor.start()
        let hotkeyManager = HotkeyManager(settings: settings, monitor: monitor)
        _settings = StateObject(wrappedValue: settings)
        _permissions = StateObject(wrappedValue: permissions)
        _monitor = StateObject(wrappedValue: monitor)
        _hotkeyManager = StateObject(wrappedValue: hotkeyManager)
    }

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(
                monitor: self.monitor,
                settings: self.settings,
                hotkeyManager: self.hotkeyManager,
                permissions: self.permissions,
                updater: self.appDelegate.updaterController)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        } label: {
            ScissorStatusLabel(monitor: self.monitor, isEnabled: self.settings.autoTrimEnabled)
        }
        Settings {
            SettingsView(
                settings: self.settings,
                hotkeyManager: self.hotkeyManager,
                monitor: self.monitor,
                permissions: self.permissions,
                updater: self.appDelegate.updaterController)
                .onAppear {
                    self.startupDiagnostics.logAccessibilityStatus()
                }
                .scenePadding()
        }
        .menuBarExtraAccess(isPresented: self.$isMenuPresented) { item in
            self.statusItem = item
            self.applyStatusItemAppearance()
        }
        .onChange(of: self.settings.autoTrimEnabled) { _, _ in
            self.applyStatusItemAppearance()
        }
        .onChange(of: self.monitor.trimPulseID) { _, _ in
            self.pulseStatusItem()
        }
        .defaultSize(width: SettingsTab.windowWidth, height: SettingsTab.windowHeight)
        .windowResizability(.contentSize)
        .windowStyle(.titleBar)
    }
}

extension TrimmyApp {
    private func applyStatusItemAppearance() {
        self.statusItem?.button?.appearsDisabled = !self.settings.autoTrimEnabled
    }

    private func pulseStatusItem() {
        guard let button = self.statusItem?.button else { return }
        button.wantsLayer = true
        if let layer = button.layer {
            let baseOpacity = layer.opacity
            let targetOpacity = max(0.25, baseOpacity * 0.4)
            let animation = CABasicAnimation(keyPath: "opacity")
            animation.fromValue = baseOpacity
            animation.toValue = targetOpacity
            animation.duration = 0.18
            animation.autoreverses = true
            animation.timingFunction = CAMediaTimingFunction(name: .easeInEaseOut)
            layer.removeAnimation(forKey: "trimPulse")
            layer.add(animation, forKey: "trimPulse")
            return
        }

        let originalAlpha = button.alphaValue
        let pulsedAlpha = max(0.25, originalAlpha * 0.4)
        button.alphaValue = pulsedAlpha
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(180))
            guard let button = self.statusItem?.button else { return }
            button.alphaValue = originalAlpha
        }
    }
}

// MARK: - Status item label

private struct ScissorStatusLabel: View {
    @ObservedObject var monitor: ClipboardMonitor
    var isEnabled: Bool

    var body: some View {
        Label {
            Text("Trimmy")
        } icon: {
            Image(systemName: "scissors")
                .symbolRenderingMode(.hierarchical)
        }
        .foregroundStyle(self.isEnabled ? AnyShapeStyle(.primary) : AnyShapeStyle(.secondary))
        .opacity(self.isEnabled ? 1.0 : 0.45)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController: UpdaterProviding = makeUpdaterController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}

// MARK: - Startup diagnostics

struct StartupDiagnostics {
    func logAccessibilityStatus() {
        let trusted = AXIsProcessTrusted()
        let bundle = Bundle.main.bundleIdentifier ?? "nil"
        let exec = Bundle.main.executableURL?.path ?? "nil"
        Telemetry.accessibility
            .info(
                """
                Startup AX trusted=\(trusted, privacy: .public) bundle=\(bundle, privacy: .public) \
                exec=\(exec, privacy: .public)
                """)
    }
}

// MARK: - Sparkle gating (disable for unsigned/dev builds)

@MainActor
protocol UpdaterProviding: AnyObject {
    var automaticallyChecksForUpdates: Bool { get set }
    var automaticallyDownloadsUpdates: Bool { get set }
    var isAvailable: Bool { get }
    var unavailableReason: String? { get }
    var updateStatus: UpdateStatus { get }
    func checkForUpdates(_ sender: Any?)
}

/// No-op updater used for debug/dev runs to suppress Sparkle dialogs.
final class DisabledUpdaterController: UpdaterProviding {
    var automaticallyChecksForUpdates: Bool = false
    var automaticallyDownloadsUpdates: Bool = false
    let isAvailable: Bool = false
    let unavailableReason: String?
    let updateStatus = UpdateStatus()

    init(unavailableReason: String? = nil) {
        self.unavailableReason = unavailableReason
    }

    func checkForUpdates(_: Any?) {}
}

@MainActor
@Observable
final class UpdateStatus {
    static let disabled = UpdateStatus()
    var isUpdateReady: Bool

    init(isUpdateReady: Bool = false) {
        self.isUpdateReady = isUpdateReady
    }
}

#if canImport(Sparkle)
import Sparkle

@MainActor
final class SparkleUpdaterController: NSObject, UpdaterProviding, SPUUpdaterDelegate {
    private lazy var controller = SPUStandardUpdaterController(
        startingUpdater: false,
        updaterDelegate: self,
        userDriverDelegate: nil)
    let updateStatus = UpdateStatus()
    let unavailableReason: String? = nil

    init(savedAutoUpdate: Bool) {
        super.init()
        let updater = self.controller.updater
        updater.automaticallyChecksForUpdates = savedAutoUpdate
        updater.automaticallyDownloadsUpdates = savedAutoUpdate
        self.controller.startUpdater()
    }

    var automaticallyChecksForUpdates: Bool {
        get { self.controller.updater.automaticallyChecksForUpdates }
        set { self.controller.updater.automaticallyChecksForUpdates = newValue }
    }

    var automaticallyDownloadsUpdates: Bool {
        get { self.controller.updater.automaticallyDownloadsUpdates }
        set { self.controller.updater.automaticallyDownloadsUpdates = newValue }
    }

    var isAvailable: Bool {
        true
    }

    func checkForUpdates(_ sender: Any?) {
        self.controller.checkForUpdates(sender)
    }

    nonisolated func updater(_ updater: SPUUpdater, didDownloadUpdate item: SUAppcastItem) {
        Task { @MainActor in
            self.updateStatus.isUpdateReady = true
        }
    }

    nonisolated func updater(_ updater: SPUUpdater, failedToDownloadUpdate item: SUAppcastItem, error: Error) {
        Task { @MainActor in
            self.updateStatus.isUpdateReady = false
        }
    }

    nonisolated func userDidCancelDownload(_ updater: SPUUpdater) {
        Task { @MainActor in
            self.updateStatus.isUpdateReady = false
        }
    }

    nonisolated func updater(
        _ updater: SPUUpdater,
        userDidMake choice: SPUUserUpdateChoice,
        forUpdate updateItem: SUAppcastItem,
        state: SPUUserUpdateState)
    {
        let downloaded = state.stage == .downloaded
        Task { @MainActor in
            switch choice {
            case .install, .skip:
                self.updateStatus.isUpdateReady = false
            case .dismiss:
                self.updateStatus.isUpdateReady = downloaded
            @unknown default:
                self.updateStatus.isUpdateReady = false
            }
        }
    }
}

private func isDeveloperIDSigned(bundleURL: URL) -> Bool {
    var staticCode: SecStaticCode?
    guard SecStaticCodeCreateWithPath(bundleURL as CFURL, SecCSFlags(), &staticCode) == errSecSuccess,
          let code = staticCode else { return false }

    var infoCF: CFDictionary?
    guard SecCodeCopySigningInformation(code, SecCSFlags(rawValue: kSecCSSigningInformation), &infoCF) == errSecSuccess,
          let info = infoCF as? [String: Any],
          let certs = info[kSecCodeInfoCertificates as String] as? [SecCertificate],
          let leaf = certs.first else { return false }

    if let summary = SecCertificateCopySubjectSummary(leaf) as String? {
        return summary.hasPrefix("Developer ID Application:")
    }
    return false
}

@MainActor
private func makeUpdaterController() -> UpdaterProviding {
    let bundleURL = Bundle.main.bundleURL
    let isBundledApp = bundleURL.pathExtension == "app"
    guard isBundledApp else {
        return DisabledUpdaterController(unavailableReason: "Updates unavailable in this build.")
    }

    if InstallOrigin.isHomebrewCask(appBundleURL: bundleURL) {
        return DisabledUpdaterController(
            unavailableReason: "Updates managed by Homebrew. Run: brew upgrade --cask steipete/tap/trimmy")
    }

    guard isDeveloperIDSigned(bundleURL: bundleURL) else {
        return DisabledUpdaterController(unavailableReason: "Updates unavailable in this build.")
    }

    let defaults = UserDefaults.standard
    let autoUpdateKey = "autoUpdateEnabled"
    // Default to true; honor the user's last choice otherwise.
    let savedAutoUpdate = (defaults.object(forKey: autoUpdateKey) as? Bool) ?? true
    return SparkleUpdaterController(savedAutoUpdate: savedAutoUpdate)
}
#else
@MainActor
private func makeUpdaterController() -> UpdaterProviding {
    DisabledUpdaterController(unavailableReason: "Updates unavailable in this build.")
}
#endif
