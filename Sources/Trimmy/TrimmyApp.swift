import AppKit
import MenuBarExtraAccess
import QuartzCore
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
                permissions: self.permissions,
                updater: self.appDelegate.updaterController)
            Divider()
            Button("Quit") { NSApplication.shared.terminate(nil) }
        } label: {
            ScissorStatusLabel(isEnabled: self.settings.autoTrimEnabled)
                .background(SettingsOpener())
        }
        .menuBarExtraAccess(isPresented: self.$isMenuPresented) { item in
            self.statusItem = item
            self.applyStatusItemAppearance()
        }
        Settings {
            SettingsView(
                settings: self.settings,
                monitor: self.monitor,
                permissions: self.permissions,
                updater: self.appDelegate.updaterController)
                .onAppear {
                    self.startupDiagnostics.logAccessibilityStatus()
                }
                .scenePadding()
        }
        .onChange(of: self.settings.autoTrimEnabled) { _, _ in
            self.applyStatusItemAppearance()
        }
        .onChange(of: self.settings.hideMenuBarIcon) { _, _ in
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
        self.statusItem?.isVisible = !self.settings.hideMenuBarIcon
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

private struct SettingsOpener: View {
    @Environment(\.openSettings) private var openSettings

    var body: some View {
        EmptyView()
            .onReceive(NotificationCenter.default.publisher(for: .trimmyOpenSettings)) { notification in
                self.open((notification.object as? SettingsTab) ?? .general)
            }
    }

    private func open(_ tab: SettingsTab) {
        SettingsTabRouter.request(tab)
        NSApp.activate(ignoringOtherApps: true)
        self.openSettings()
        NotificationCenter.default.post(name: .trimmySelectSettingsTab, object: tab)
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let updaterController: UpdaterProviding = makeUpdaterController()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        NotificationCenter.default.post(name: .trimmyOpenSettings, object: SettingsTab.general)
        return false
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
