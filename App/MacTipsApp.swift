import SwiftUI
import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    lazy var coordinator = AppCoordinator()

    func applicationDidFinishLaunching(_ notification: Notification) {
        _ = coordinator
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        coordinator.showSettings()
        return false
    }
}

@main
struct MacTipsApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @ObservedObject private var settings = SettingsStore.shared

    var body: some Scene {
        MenuBarExtra("MacTips", systemImage: "capslock", isInserted: Binding(
            get: { settings.showMenuBarIcon },
            set: { if settings.showMenuBarIcon != $0 { settings.showMenuBarIcon = $0 } }
        )) {
            MenuBarView(coordinator: appDelegate.coordinator)
                .environment(\.locale, settings.activeLocale)
        }
        .menuBarExtraStyle(.menu)
    }
}
