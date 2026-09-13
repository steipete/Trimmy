import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var monitor: ClipboardMonitor
    @ObservedObject var permissions: AccessibilityPermissionManager
    weak var updater: UpdaterProviding?
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: self.$selectedTab) {
            GeneralSettingsPane(settings: self.settings, permissions: self.permissions)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            TrimmingSettingsPane(settings: self.settings)
                .tabItem { Label("Trimming", systemImage: "slider.horizontal.3") }
                .tag(SettingsTab.trimming)

            RulesSettingsPane(settings: self.settings)
                .tabItem { Label("Rules", systemImage: "list.bullet.rectangle.portrait") }
                .tag(SettingsTab.rules)

            HotkeySettingsPane(settings: self.settings)
                .tabItem { Label("Shortcuts", systemImage: "command") }
                .tag(SettingsTab.shortcuts)

            AdvancedSettingsPane(settings: self.settings)
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
                .tag(SettingsTab.advanced)

            #if DEBUG
            if self.settings.debugPaneEnabled {
                DebugSettingsPane(monitor: self.monitor)
                    .tabItem { Label("Debug", systemImage: "ant.fill") }
                    .tag(SettingsTab.debug)
            }
            #endif

            AboutPane(updater: self.updater)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .frame(width: SettingsTab.windowWidth, height: SettingsTab.windowHeight, alignment: .topLeading)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onReceive(NotificationCenter.default.publisher(for: .trimmySelectSettingsTab)) { notification in
            guard let tab = notification.object as? SettingsTab else { return }
            self.select(tab, animate: true)
        }
        .onAppear {
            let initial = SettingsTabRouter.consumePending() ?? self.selectedTab
            self.select(initial, animate: false)
        }
    }

    private func select(_ tab: SettingsTab, animate: Bool) {
        if animate {
            withAnimation(.spring(response: 0.32, dampingFraction: 0.85)) {
                self.selectedTab = tab
            }
        } else {
            self.selectedTab = tab
        }
    }
}

enum SettingsTab: String, Hashable, CaseIterable, Codable {
    case general, trimming, rules, shortcuts, advanced, about
    #if DEBUG
    case debug
    #endif

    static let windowWidth: CGFloat = 560
    static let windowHeight: CGFloat = 620
}

extension Notification.Name {
    static let trimmySelectSettingsTab = Notification.Name("trimmySelectSettingsTab")
    static let trimmyOpenSettings = Notification.Name("trimmyOpenSettings")
}

@MainActor
enum SettingsTabRouter {
    private static var pending: SettingsTab?

    static func request(_ tab: SettingsTab) {
        self.pending = tab
    }

    static func consumePending() -> SettingsTab? {
        defer { self.pending = nil }
        return self.pending
    }
}
