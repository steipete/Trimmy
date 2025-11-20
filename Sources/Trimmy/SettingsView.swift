import SwiftUI

@MainActor
struct SettingsView: View {
    @ObservedObject var settings: AppSettings
    @ObservedObject var hotkeyManager: HotkeyManager
    weak var updater: UpdaterProviding?
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        TabView(selection: self.$selectedTab) {
            GeneralSettingsPane(settings: self.settings)
                .tabItem { Label("General", systemImage: "gearshape") }
                .tag(SettingsTab.general)

            AggressivenessSettingsPane(settings: self.settings)
                .tabItem { Label("Aggressiveness", systemImage: "speedometer") }
                .tag(SettingsTab.aggressiveness)

            HotkeySettingsPane(settings: self.settings, hotkeyManager: self.hotkeyManager)
                .tabItem { Label("Shortcuts", systemImage: "command") }
                .tag(SettingsTab.shortcuts)

            AboutPane(updater: self.updater)
                .tabItem { Label("About", systemImage: "info.circle") }
                .tag(SettingsTab.about)
        }
        .padding(12)
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
    case general, aggressiveness, shortcuts, about

    static let windowWidth: CGFloat = 400
    static let windowHeight: CGFloat = 396
}

extension Notification.Name {
    static let trimmySelectSettingsTab = Notification.Name("trimmySelectSettingsTab")
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
